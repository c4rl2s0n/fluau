//! Generic crypto primitives for plugins that declare the `crypto` host permission.
//!
//! No provider-specific APIs (no SRP / Proton helpers). Plugins compose these
//! building blocks in Luau.

use base64::{engine::general_purpose::STANDARD as B64, Engine};
use bcrypt::{hash_with_salt, Version};
use md5::{Digest as Md5Digest, Md5};
use num_bigint::BigUint;
use num_traits::{One, Zero};
use serde_json::{json, Value};
use sha2::{Digest, Sha256, Sha512};

pub fn dispatch(method: &str, args: &Value) -> Result<Value, String> {
    match method {
        "sha256" => hash_digest::<Sha256>(args),
        "sha512" => hash_digest::<Sha512>(args),
        "md5" => hash_md5(args),
        "randomBytes" => random_bytes(args),
        "bcrypt" => bcrypt_hash(args),
        "modPow" => mod_pow(args),
        "base64Encode" => base64_encode(args),
        "base64Decode" => base64_decode(args),
        other => Err(format!("unknown crypto method: {other}")),
    }
}

fn hash_digest<D: Digest>(args: &Value) -> Result<Value, String> {
    let data = decode_input(args)?;
    let digest = D::digest(&data);
    Ok(json!({ "hex": hex::encode(&digest), "base64": B64.encode(&digest) }))
}

fn hash_md5(args: &Value) -> Result<Value, String> {
    let data = decode_input(args)?;
    let digest = Md5::digest(&data);
    Ok(json!({ "hex": hex::encode(digest), "base64": B64.encode(digest) }))
}

fn decode_input(args: &Value) -> Result<Vec<u8>, String> {
    if let Some(s) = args.get("utf8").and_then(|v| v.as_str()) {
        return Ok(s.as_bytes().to_vec());
    }
    if let Some(s) = args.get("base64").and_then(|v| v.as_str()) {
        return B64.decode(s).map_err(|e| format!("invalid base64: {e}"));
    }
    if let Some(s) = args.get("hex").and_then(|v| v.as_str()) {
        return hex::decode(s).map_err(|e| format!("invalid hex: {e}"));
    }
    Err("crypto input requires utf8, base64, or hex".into())
}

fn random_bytes(args: &Value) -> Result<Value, String> {
    let n = args
        .get("n")
        .and_then(|v| v.as_u64())
        .ok_or("crypto.randomBytes requires n")? as usize;
    if n == 0 || n > 4096 {
        return Err("crypto.randomBytes: n must be 1..=4096".into());
    }
    let mut buf = vec![0u8; n];
    getrandom::getrandom(&mut buf).map_err(|e| e.to_string())?;
    Ok(json!({ "base64": B64.encode(&buf), "hex": hex::encode(&buf) }))
}

/// bcrypt cost-10 with a 16-byte salt (raw bytes via base64).
/// Returns the full `$2y$10$...` hash string (utf8 + base64 of those bytes).
fn bcrypt_hash(args: &Value) -> Result<Value, String> {
    let password = args
        .get("password")
        .and_then(|v| v.as_str())
        .ok_or("crypto.bcrypt requires password")?;
    let salt_b64 = args
        .get("saltBase64")
        .and_then(|v| v.as_str())
        .ok_or("crypto.bcrypt requires saltBase64 (16 raw bytes)")?;
    let salt = B64
        .decode(salt_b64)
        .map_err(|e| format!("invalid saltBase64: {e}"))?;
    let salt_arr: [u8; 16] = salt
        .try_into()
        .map_err(|_| "crypto.bcrypt salt must be exactly 16 bytes".to_string())?;
    let cost = args.get("cost").and_then(|v| v.as_u64()).unwrap_or(10) as u32;
    let hashed = hash_with_salt(password, cost, salt_arr)
        .map_err(|e| format!("bcrypt failed: {e}"))?
        .format_for_version(Version::TwoY);
    Ok(json!({
        "hash": hashed.clone(),
        "base64": B64.encode(hashed.as_bytes()),
        "hex": hex::encode(hashed.as_bytes()),
    }))
}

/// (base ^ exp) mod modulus. All operands are **big-endian** byte strings (base64).
/// Result is big-endian base64, optionally zero-padded to `pad` bytes.
fn mod_pow(args: &Value) -> Result<Value, String> {
    let base = decode_b64_field(args, "base")?;
    let exp = decode_b64_field(args, "exp")?;
    let modulus = decode_b64_field(args, "mod")?;
    if modulus.iter().all(|&b| b == 0) {
        return Err("crypto.modPow: modulus must be non-zero".into());
    }
    let base_n = BigUint::from_bytes_be(&base);
    let exp_n = BigUint::from_bytes_be(&exp);
    let mod_n = BigUint::from_bytes_be(&modulus);
    if mod_n.is_zero() || mod_n.is_one() {
        return Err("crypto.modPow: invalid modulus".into());
    }
    let result = base_n.modpow(&exp_n, &mod_n);
    let mut out = result.to_bytes_be();
    if let Some(pad) = args.get("pad").and_then(|v| v.as_u64()) {
        let pad = pad as usize;
        if out.len() > pad {
            return Err("crypto.modPow: result longer than pad".into());
        }
        if out.len() < pad {
            let mut padded = vec![0u8; pad - out.len()];
            padded.append(&mut out);
            out = padded;
        }
    }
    Ok(json!({ "base64": B64.encode(&out), "hex": hex::encode(&out) }))
}

fn decode_b64_field(args: &Value, key: &str) -> Result<Vec<u8>, String> {
    let s = args
        .get(key)
        .and_then(|v| v.as_str())
        .ok_or_else(|| format!("crypto.modPow requires {key}"))?;
    B64.decode(s).map_err(|e| format!("invalid {key} base64: {e}"))
}

fn base64_encode(args: &Value) -> Result<Value, String> {
    let data = decode_input(args)?;
    Ok(json!({ "base64": B64.encode(&data) }))
}

fn base64_decode(args: &Value) -> Result<Value, String> {
    let s = args
        .get("base64")
        .and_then(|v| v.as_str())
        .ok_or("crypto.base64Decode requires base64")?;
    let data = B64.decode(s).map_err(|e| format!("invalid base64: {e}"))?;
    Ok(json!({ "hex": hex::encode(&data), "base64": B64.encode(&data), "len": data.len() }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn mod_pow_smoke() {
        // 3^5 mod 13 = 243 mod 13 = 9
        let r = mod_pow(&json!({
            "base": B64.encode([3u8]),
            "exp": B64.encode([5u8]),
            "mod": B64.encode([13u8]),
        }))
        .unwrap();
        let out = B64.decode(r["base64"].as_str().unwrap()).unwrap();
        assert_eq!(*out.last().unwrap(), 9);
    }

    #[test]
    fn bcrypt_16_byte_salt() {
        let salt = [1u8; 16];
        let r = bcrypt_hash(&json!({
            "password": "abc123",
            "saltBase64": B64.encode(salt),
        }))
        .unwrap();
        let hash = r["hash"].as_str().unwrap();
        assert!(hash.starts_with("$2y$10$"), "{hash}");
    }
}
