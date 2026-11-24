//! `host.crypto` module — trait contract + Host impl.

use host_api_macros::host_module;
use serde_json::{json, Value as JsonValue};

use super::crypto;
use lua_plugin_core::Host;
use lua_plugin_core::PermissionGate;
use super::types::{
    CryptoBase64DecodeOpts, CryptoBase64DecodeResult, CryptoBase64EncodeResult, CryptoBcryptOpts,
    CryptoBcryptResult, CryptoBytesInput, CryptoDigestResult, CryptoModPowOpts, CryptoModPowResult,
    CryptoRandomOpts, CryptoRandomResult,
};

#[host_module(
    path = "crypto",
    permission = "crypto",
    summary = "Generic cryptographic primitives"
)]
pub trait HostCrypto {
    #[lua(name = "sha256")]
    fn sha256(&self, input: CryptoBytesInput) -> Result<CryptoDigestResult, String>;

    #[lua(name = "sha512")]
    fn sha512(&self, input: CryptoBytesInput) -> Result<CryptoDigestResult, String>;

    #[lua(name = "md5")]
    fn md5(&self, input: CryptoBytesInput) -> Result<CryptoDigestResult, String>;

    #[lua(name = "randomBytes")]
    fn random_bytes(&self, opts: CryptoRandomOpts) -> Result<CryptoRandomResult, String>;

    #[lua(name = "bcrypt")]
    fn bcrypt(&self, opts: CryptoBcryptOpts) -> Result<CryptoBcryptResult, String>;

    #[lua(name = "modPow")]
    fn mod_pow(&self, opts: CryptoModPowOpts) -> Result<CryptoModPowResult, String>;

    #[lua(name = "base64Encode")]
    fn base64_encode(&self, input: CryptoBytesInput) -> Result<CryptoBase64EncodeResult, String>;

    #[lua(name = "base64Decode")]
    fn base64_decode(
        &self,
        opts: CryptoBase64DecodeOpts,
    ) -> Result<CryptoBase64DecodeResult, String>;
}

impl HostCrypto for Host {
    fn sha256(&self, input: CryptoBytesInput) -> Result<CryptoDigestResult, String> {
        PermissionGate::require(&self.plugin_id, "crypto")?;
        digest_from_dispatch("sha256", &bytes_to_json(&input))
    }

    fn sha512(&self, input: CryptoBytesInput) -> Result<CryptoDigestResult, String> {
        PermissionGate::require(&self.plugin_id, "crypto")?;
        digest_from_dispatch("sha512", &bytes_to_json(&input))
    }

    fn md5(&self, input: CryptoBytesInput) -> Result<CryptoDigestResult, String> {
        PermissionGate::require(&self.plugin_id, "crypto")?;
        digest_from_dispatch("md5", &bytes_to_json(&input))
    }

    fn random_bytes(&self, opts: CryptoRandomOpts) -> Result<CryptoRandomResult, String> {
        PermissionGate::require(&self.plugin_id, "crypto")?;
        let v = crypto::dispatch("randomBytes", &json!({ "n": opts.n }))?;
        Ok(CryptoRandomResult {
            hex: req_str(&v, "hex")?,
            base64: req_str(&v, "base64")?,
        })
    }

    fn bcrypt(&self, opts: CryptoBcryptOpts) -> Result<CryptoBcryptResult, String> {
        PermissionGate::require(&self.plugin_id, "crypto")?;
        let mut args = json!({
            "password": opts.password,
            "saltBase64": opts.salt_base64,
        });
        if let Some(cost) = opts.cost {
            args.as_object_mut()
                .unwrap()
                .insert("cost".into(), json!(cost));
        }
        let v = crypto::dispatch("bcrypt", &args)?;
        Ok(CryptoBcryptResult {
            hash: req_str(&v, "hash")?,
            base64: req_str(&v, "base64")?,
            hex: req_str(&v, "hex")?,
        })
    }

    fn mod_pow(&self, opts: CryptoModPowOpts) -> Result<CryptoModPowResult, String> {
        PermissionGate::require(&self.plugin_id, "crypto")?;
        let mut args = json!({
            "base": opts.base,
            "exp": opts.exp,
            "mod": opts.modulus,
        });
        if let Some(pad) = opts.pad {
            args.as_object_mut()
                .unwrap()
                .insert("pad".into(), json!(pad));
        }
        let v = crypto::dispatch("modPow", &args)?;
        Ok(CryptoModPowResult {
            base64: req_str(&v, "base64")?,
            hex: v.get("hex").and_then(|x| x.as_str()).map(|s| s.to_string()),
        })
    }

    fn base64_encode(&self, input: CryptoBytesInput) -> Result<CryptoBase64EncodeResult, String> {
        PermissionGate::require(&self.plugin_id, "crypto")?;
        let v = crypto::dispatch("base64Encode", &bytes_to_json(&input))?;
        Ok(CryptoBase64EncodeResult {
            base64: req_str(&v, "base64")?,
        })
    }

    fn base64_decode(
        &self,
        opts: CryptoBase64DecodeOpts,
    ) -> Result<CryptoBase64DecodeResult, String> {
        PermissionGate::require(&self.plugin_id, "crypto")?;
        let v = crypto::dispatch("base64Decode", &json!({ "base64": opts.base64 }))?;
        Ok(CryptoBase64DecodeResult {
            hex: req_str(&v, "hex")?,
            base64: req_str(&v, "base64")?,
            len: v
                .get("len")
                .and_then(|x| x.as_u64())
                .ok_or_else(|| "crypto.base64Decode missing len".to_string())?,
        })
    }
}

fn bytes_to_json(input: &CryptoBytesInput) -> JsonValue {
    let mut map = serde_json::Map::new();
    if let Some(s) = &input.utf8 {
        map.insert("utf8".into(), JsonValue::String(s.clone()));
    }
    if let Some(s) = &input.base64 {
        map.insert("base64".into(), JsonValue::String(s.clone()));
    }
    if let Some(s) = &input.hex {
        map.insert("hex".into(), JsonValue::String(s.clone()));
    }
    JsonValue::Object(map)
}

fn digest_from_dispatch(method: &str, args: &JsonValue) -> Result<CryptoDigestResult, String> {
    let v = crypto::dispatch(method, args)?;
    Ok(CryptoDigestResult {
        hex: req_str(&v, "hex")?,
        base64: req_str(&v, "base64")?,
    })
}

fn req_str(v: &JsonValue, key: &str) -> Result<String, String> {
    v.get(key)
        .and_then(|x| x.as_str())
        .map(|s| s.to_string())
        .ok_or_else(|| format!("crypto response missing {key}"))
}
