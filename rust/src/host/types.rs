//! Typed DTOs for the Lua-visible host API boundary.

use std::collections::HashMap;

use host_api_macros::HostType;
use serde::{Deserialize, Serialize};
use serde_json::Value as JsonValue;

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct HttpRequestOpts {
    #[serde(default)]
    pub method: Option<String>,
    pub url: String,
    #[serde(default)]
    pub body: Option<JsonValue>,
    #[serde(default)]
    pub headers: Option<HashMap<String, String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct HttpResponse {
    pub ok: bool,
    pub status: i64,
    #[serde(default)]
    pub body: Option<JsonValue>,
    #[serde(default)]
    pub headers: Option<HashMap<String, JsonValue>>,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoBytesInput {
    #[serde(default)]
    pub utf8: Option<String>,
    #[serde(default)]
    pub base64: Option<String>,
    #[serde(default)]
    pub hex: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoDigestResult {
    pub hex: String,
    pub base64: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoRandomOpts {
    pub n: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoRandomResult {
    pub hex: String,
    pub base64: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoBcryptOpts {
    pub password: String,
    #[serde(rename = "saltBase64")]
    pub salt_base64: String,
    #[serde(default)]
    pub cost: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoBcryptResult {
    pub hash: String,
    pub base64: String,
    pub hex: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoModPowOpts {
    pub base: String,
    pub exp: String,
    #[serde(rename = "mod")]
    pub modulus: String,
    #[serde(default)]
    pub pad: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoModPowResult {
    pub base64: String,
    #[serde(default)]
    pub hex: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoBase64EncodeResult {
    pub base64: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoBase64DecodeOpts {
    pub base64: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, HostType)]
pub struct CryptoBase64DecodeResult {
    pub hex: String,
    pub base64: String,
    pub len: u64,
}
