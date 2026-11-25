//! Example HostAPIs and intent handlers (app-owned (not part of the fluau crate)).

pub mod crypto;
pub mod crypto_api;
pub mod db;
pub mod db_api;
pub mod http;
pub mod http_api;
pub mod http_client;
pub mod log_api;
pub mod types;

use fluau::{
    Host, HostApiEntry, IntentOutcome, PermissionGate, PermissionUse, SessionGrants,
    SetupOptions, set_session_cleanup, set_session_prepare, setup,
};
use mlua::{Lua, Result as LuaResult, Table};
use serde_json::{json, Value};
use std::sync::Once;

use crypto_api::HostCrypto;
use db_api::HostDb;
use http_api::HostHttp;
use log_api::HostLog;

static INIT: Once = Once::new();

fn install_db(root: &Table, host: Host, lua: &Lua) -> LuaResult<()> {
    HostDb::install_into(root, host, lua)
}
fn install_http(root: &Table, host: Host, lua: &Lua) -> LuaResult<()> {
    HostHttp::install_into(root, host, lua)
}
fn install_crypto(root: &Table, host: Host, lua: &Lua) -> LuaResult<()> {
    HostCrypto::install_into(root, host, lua)
}
fn install_log(root: &Table, host: Host, lua: &Lua) -> LuaResult<()> {
    HostLog::install_into(root, host, lua)
}

fn http_domain_checker(constraints: &Value, ctx: &Value) -> Result<(), String> {
    let url = ctx.get("url").and_then(|u| u.as_str()).unwrap_or("");
    let domains = constraints
        .get("domains")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|x| x.as_str().map(|s| s.to_string()))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    if domains.is_empty() {
        return Err("permission denied: http granted but domains allowlist is empty".into());
    }
    if http::host_allowed(url, &domains) {
        Ok(())
    } else {
        Err(format!(
            "host not allowed by plugin http domains: {}",
            http::host_of(url).unwrap_or_else(|| url.to_string())
        ))
    }
}

fn intent_http(plugin_id: &str, intent: &Value) -> Result<Option<IntentOutcome>, String> {
    let request_id = intent.get("requestId").cloned().unwrap_or(Value::Null);
    let method = intent
        .get("method")
        .and_then(|v| v.as_str())
        .unwrap_or("GET");
    let url = intent.get("url").and_then(|v| v.as_str()).unwrap_or("");
    PermissionGate::require_with(
        plugin_id,
        "http",
        &PermissionUse::Context(json!({ "url": url })),
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
        let mut response = client.request_unchecked(&opts);
        if let Value::Object(ref mut map) = response {
            map.insert("type".into(), json!("http"));
            map.insert("requestId".into(), request_id.clone());
        }
        response
    })?;
    Ok(Some(IntentOutcome::HostResult(response)))
}

fn intent_db_set(plugin_id: &str, intent: &Value) -> Result<Option<IntentOutcome>, String> {
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
    Ok(Some(IntentOutcome::HostResult(json!({
        "type": "db.set",
        "requestId": intent.get("requestId"),
        "ok": true
    }))))
}

fn intent_db_get(plugin_id: &str, intent: &Value) -> Result<Option<IntentOutcome>, String> {
    PermissionGate::require(plugin_id, "db")?;
    let key = intent.get("key").and_then(|v| v.as_str()).unwrap_or("");
    let value = db::get(plugin_id, key)?;
    Ok(Some(IntentOutcome::HostResult(json!({
        "type": "db.get",
        "requestId": intent.get("requestId"),
        "key": key,
        "value": value
    }))))
}

fn prepare_session(plugin_id: &str, grants: &SessionGrants) -> Result<(), String> {
    let http_domains = grants
        .host
        .get("http")
        .and_then(|c| c.get("domains"))
        .and_then(|d| d.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|x| x.as_str().map(|s| s.to_string()))
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();
    http_client::configure(plugin_id, http_domains)
}

fn cleanup_session(plugin_id: &str) {
    http_client::clear_client(plugin_id);
}

/// Register demo HostAPIs, intents, HTTP checker, UI catalog, and session hooks.
pub fn setup_example_runtime() -> Result<(), String> {
    setup(SetupOptions {
        host_apis: vec![
            HostApiEntry {
                id: "db".into(),
                path: "db".into(),
                summary: "Per-plugin key-value storage".into(),
                install: install_db,
            },
            HostApiEntry {
                id: "http".into(),
                path: "http".into(),
                summary: "Outbound HTTP to allowlisted domains".into(),
                install: install_http,
            },
            HostApiEntry {
                id: "crypto".into(),
                path: "crypto".into(),
                summary: "Generic cryptographic primitives".into(),
                install: install_crypto,
            },
            HostApiEntry {
                id: "log".into(),
                path: "log".into(),
                summary: "Diagnostic logging to the host".into(),
                install: install_log,
            },
        ],
        intent_handlers: vec![
            ("http".into(), intent_http),
            ("db.set".into(), intent_db_set),
            ("db.get".into(), intent_db_get),
        ],
        constraint_checkers: vec![("http".into(), http_domain_checker)],
        ui_setup: Some(crate::lua_engine::setup_lua_api),
    })?;
    set_session_prepare(prepare_session)?;
    set_session_cleanup(cleanup_session)?;
    Ok(())
}

/// Idempotent setup for FRB init / tests.
pub fn ensure_runtime() {
    INIT.call_once(|| {
        if let Err(e) = setup_example_runtime() {
            eprintln!("lua_plugin demo setup failed: {e}");
        }
    });
}
