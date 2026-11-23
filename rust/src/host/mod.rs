//! Rust-side host APIs used while draining plugin intents and sync Lua `host.*`.

pub mod api_registry;
pub mod crypto;
pub mod crypto_api;
pub mod db;
pub mod db_api;
pub mod facade;
pub mod http;
pub mod http_api;
pub mod http_client;
pub mod log_api;
pub mod permissions;
pub mod types;

pub use facade::Host;
pub use http_api::HttpClient;
pub use permissions::{PermissionGate, PermissionUse, SessionGrants};
pub use types::*;

use serde_json::{json, Value};

/// Execute one host intent. Returns:
/// - `Ok(Some(result))` for db/http (feed to `on_host_result`)
/// - `Ok(None)` for `app.provideResult` (caller collects the value)
/// - `Err` on failure
pub fn execute_intent(plugin_id: &str, intent: &Value) -> Result<IntentOutcome, String> {
    let intent_type = intent
        .get("type")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown");

    match intent_type {
        "http" => {
            let request_id = intent.get("requestId").cloned().unwrap_or(Value::Null);
            let method = intent
                .get("method")
                .and_then(|v| v.as_str())
                .unwrap_or("GET");
            let url = intent.get("url").and_then(|v| v.as_str()).unwrap_or("");
            PermissionGate::require_with(
                plugin_id,
                "http",
                &PermissionUse::Http {
                    url: url.to_string(),
                },
            )?;
            let body = intent.get("body");
            let headers = intent.get("headers");
            let response = http_client::with_client(plugin_id, |client| {
                let mut opts = json!({
                    "method": method,
                    "url": url,
                });
                if let Some(b) = body {
                    opts.as_object_mut().unwrap().insert("body".into(), b.clone());
                }
                if let Some(h) = headers {
                    opts.as_object_mut()
                        .unwrap()
                        .insert("headers".into(), h.clone());
                }
                // Gate already checked domains; skip client allowlist double-deny by
                // using an empty allowlist on the intent path (client still used for cookies).
                let mut response = client.request_unchecked(&opts);
                if let Value::Object(ref mut map) = response {
                    map.insert("type".into(), json!("http"));
                    map.insert("requestId".into(), request_id.clone());
                }
                response
            })?;
            Ok(IntentOutcome::HostResult(response))
        }
        "db.set" => {
            PermissionGate::require(plugin_id, "db")?;
            let key = intent.get("key").and_then(|v| v.as_str()).unwrap_or("");
            let value = intent
                .get("value")
                .map(|v| match v {
                    Value::String(s) => s.clone(),
                    other => other.to_string(),
                })
                .unwrap_or_default();
            db::set(plugin_id, key, &value)?;
            Ok(IntentOutcome::HostResult(json!({
                "type": "db.set",
                "requestId": intent.get("requestId"),
                "ok": true
            })))
        }
        "db.get" => {
            PermissionGate::require(plugin_id, "db")?;
            let key = intent.get("key").and_then(|v| v.as_str()).unwrap_or("");
            let value = db::get(plugin_id, key)?;
            Ok(IntentOutcome::HostResult(json!({
                "type": "db.get",
                "requestId": intent.get("requestId"),
                "key": key,
                "value": value
            })))
        }
        "app.provideResult" => {
            let value = intent
                .get("value")
                .map(|v| match v {
                    Value::String(s) => s.clone(),
                    other => other.to_string(),
                })
                .unwrap_or_default();
            let request_id = intent.get("requestId").cloned();
            Ok(IntentOutcome::ProvideResult {
                value,
                ack: json!({
                    "type": "app.provideResult",
                    "requestId": request_id,
                    "ok": true
                }),
            })
        }
        other => Ok(IntentOutcome::HostResult(json!({
            "type": other,
            "requestId": intent.get("requestId"),
            "error": "unknown intent type",
            "ok": false
        }))),
    }
}

#[derive(Debug)]
pub enum IntentOutcome {
    HostResult(Value),
    ProvideResult { value: String, ack: Value },
}
