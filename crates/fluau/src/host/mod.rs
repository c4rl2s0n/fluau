//! Host surface infrastructure (registry, gate, intents). Concrete HostApis live in the app.

pub mod api_registry;
pub mod facade;
pub mod permissions;

pub use api_registry::{HostApiEntry, inject_granted, list_host_apis, register_host_api, set_host_apis};
pub use facade::Host;
pub use permissions::{PermissionGate, PermissionUse, SessionGrants};

use lazy_static::lazy_static;
use serde_json::{json, Value};
use std::sync::Mutex;

/// Outcome of executing one host intent.
#[derive(Debug)]
pub enum IntentOutcome {
    HostResult(Value),
    ProvideResult { value: String, ack: Value },
}

pub type IntentHandler = fn(plugin_id: &str, intent: &Value) -> Result<Option<IntentOutcome>, String>;

lazy_static! {
    static ref INTENT_HANDLERS: Mutex<Vec<(String, IntentHandler)>> = Mutex::new(Vec::new());
}

/// Register an intent type handler (e.g. `"http"`, `"db.set"`). App-provided.
pub fn register_intent_handler(intent_type: &str, handler: IntentHandler) -> Result<(), String> {
    let mut list = INTENT_HANDLERS.lock().map_err(|e| e.to_string())?;
    list.retain(|(t, _)| t != intent_type);
    list.push((intent_type.to_string(), handler));
    Ok(())
}

pub fn clear_intent_handlers() {
    if let Ok(mut list) = INTENT_HANDLERS.lock() {
        list.clear();
    }
}

/// Execute one host intent via registered handlers + built-in `app.provideResult`.
pub fn execute_intent(plugin_id: &str, intent: &Value) -> Result<IntentOutcome, String> {
    let intent_type = intent
        .get("type")
        .and_then(|v| v.as_str())
        .unwrap_or("unknown");

    if intent_type == "app.provideResult" {
        let value = intent
            .get("value")
            .map(|v| match v {
                Value::String(s) => s.clone(),
                other => other.to_string(),
            })
            .unwrap_or_default();
        let request_id = intent.get("requestId").cloned();
        return Ok(IntentOutcome::ProvideResult {
            value,
            ack: json!({
                "type": "app.provideResult",
                "requestId": request_id,
                "ok": true
            }),
        });
    }

    let handlers = INTENT_HANDLERS.lock().map_err(|e| e.to_string())?;
    for (ty, handler) in handlers.iter() {
        if ty == intent_type {
            if let Some(outcome) = handler(plugin_id, intent)? {
                return Ok(outcome);
            }
        }
    }

    Ok(IntentOutcome::HostResult(json!({
        "type": intent_type,
        "requestId": intent.get("requestId"),
        "error": "unknown intent type",
        "ok": false
    })))
}
