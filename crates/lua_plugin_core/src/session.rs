//! Persistent Luau plugin sessions (sandboxed).
//!
//! Each plugin id owns one long-lived Lua VM. UI is produced by `render()`,
//! interactions arrive as JSON events via `on_event`. Host intents (`db` /
//! `http` / `app.provideResult`) are drained on the Rust host layer.

use crate::host::{self, api_registry, IntentOutcome, PermissionGate};
use crate::json_util::{
    json_to_lua, value_to_intents_json, value_to_widget_json,
};
use crate::registry::{self, PluginGrants, PluginPermissions};
use crate::ui;
use lazy_static::lazy_static;
use mlua::{Function, Lua, Value};
use serde_json::Value as JsonValue;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

lazy_static! {
    static ref SESSIONS: Mutex<HashMap<String, Lua>> = Mutex::new(HashMap::new());
    /// Optional per-session prepare hook (e.g. sync HTTP allowlist from grants).
    static ref SESSION_PREPARE: Mutex<Option<SessionPrepareFn>> = Mutex::new(None);
    static ref SESSION_CLEANUP: Mutex<Option<SessionCleanupFn>> = Mutex::new(None);
}

pub type SessionPrepareFn =
    fn(plugin_id: &str, grants: &host::SessionGrants) -> Result<(), String>;
pub type SessionCleanupFn = fn(plugin_id: &str);

pub fn set_session_prepare(f: SessionPrepareFn) -> Result<(), String> {
    let mut slot = SESSION_PREPARE.lock().map_err(|e| e.to_string())?;
    *slot = Some(f);
    Ok(())
}

pub fn set_session_cleanup(f: SessionCleanupFn) -> Result<(), String> {
    let mut slot = SESSION_CLEANUP.lock().map_err(|e| e.to_string())?;
    *slot = Some(f);
    Ok(())
}

/// Result of running a plugin entrypoint that may request host work.
#[derive(Clone, Debug)]
pub struct PluginResponse {
    pub widget_json: String,
    /// Values from `app.provideResult` intents collected while draining.
    pub provide_results: Vec<String>,
}

/// Create (or replace) a plugin session with explicit permissions and grants.
pub fn start_plugin_with_modules(
    plugin_id: &str,
    script: &str,
    modules: HashMap<String, String>,
    permissions: PluginPermissions,
    grants: PluginGrants,
) -> Result<(), String> {
    let session_grants = registry::resolve_session_grants(&permissions, &grants)?;

    PermissionGate::clear(plugin_id);
    PermissionGate::bind(plugin_id, session_grants.clone())?;

    if let Ok(slot) = SESSION_PREPARE.lock() {
        if let Some(prepare) = *slot {
            prepare(plugin_id, &session_grants)?;
        }
    }

    let granted_apis: Vec<String> = session_grants.host.keys().cloned().collect();

    let lua = Lua::new();
    ui::install_ui(&lua).map_err(|e| e.to_string())?;
    inject_require(&lua, plugin_id, modules).map_err(|e| e.to_string())?;
    let host = host::Host::new(plugin_id);
    api_registry::inject_granted(&lua, host, &granted_apis).map_err(|e| e.to_string())?;

    // Luau sandbox: libs/globals read-only; local env for script writes.
    lua.sandbox(true)
        .map_err(|e| format!("sandbox enable failed: {e}"))?;

    lua.load(script)
        .exec()
        .map_err(|e| format!("failed to load plugin script: {e}"))?;

    if let Ok(init) = lua.globals().get::<Function>("init") {
        init.call::<()>(())
            .map_err(|e| format!("init() failed: {e}"))?;
    }

    let mut sessions = SESSIONS.lock().map_err(|e| e.to_string())?;
    sessions.insert(plugin_id.to_string(), lua);
    Ok(())
}

/// Create a session with no package modules (script only).
pub fn start_plugin(
    plugin_id: &str,
    script: &str,
    permissions: PluginPermissions,
    grants: PluginGrants,
) -> Result<(), String> {
    start_plugin_with_modules(plugin_id, script, HashMap::new(), permissions, grants)
}

fn inject_require(
    lua: &Lua,
    plugin_id: &str,
    modules: HashMap<String, String>,
) -> mlua::Result<()> {
    let modules = Arc::new(modules);
    let loaded: Arc<Mutex<HashMap<String, Value>>> = Arc::new(Mutex::new(HashMap::new()));
    let pid = plugin_id.to_string();

    let require_fn = lua.create_function(move |lua, name: String| {
        // Package-local only: modules registered with this plugin. No third-party /
        // filesystem package.path; PermissionGate is not involved for require.
        if let Ok(cache) = loaded.lock() {
            if let Some(v) = cache.get(&name) {
                return Ok(v.clone());
            }
        }

        let source = modules.get(&name).cloned().ok_or_else(|| {
            mlua::Error::runtime(format!(
                "module '{name}' not found in plugin '{pid}' package"
            ))
        })?;

        let result: Value = lua
            .load(&source)
            .set_name(&format!("@{name}"))
            .eval()
            .map_err(|e| mlua::Error::runtime(format!("failed to load module '{name}': {e}")))?;

        if let Ok(mut cache) = loaded.lock() {
            cache.insert(name, result.clone());
        }
        Ok(result)
    })?;

    lua.globals().set("require", require_fn)?;
    Ok(())
}

/// Start a session from a registered plugin id with explicit grants.
pub fn start_registered_plugin_with_grants(
    plugin_id: &str,
    grants: PluginGrants,
) -> Result<(), String> {
    let script = registry::get_script(plugin_id)?;
    let modules = registry::get_modules(plugin_id)?;
    let manifest = registry::get_plugin(plugin_id)?;
    start_plugin_with_modules(
        plugin_id,
        &script,
        modules,
        manifest.permissions,
        grants,
    )
}

/// Start a session granting every permission the manifest requests.
pub fn start_registered_plugin(plugin_id: &str) -> Result<(), String> {
    let manifest = registry::get_plugin(plugin_id)?;
    let grants = PluginGrants::all_requested(&manifest.permissions);
    start_registered_plugin_with_grants(plugin_id, grants)
}

/// Drop a plugin session.
pub fn stop_plugin(plugin_id: &str) -> Result<(), String> {
    let mut sessions = SESSIONS.lock().map_err(|e| e.to_string())?;
    sessions.remove(plugin_id);
    PermissionGate::clear(plugin_id);
    if let Ok(slot) = SESSION_CLEANUP.lock() {
        if let Some(cleanup) = *slot {
            cleanup(plugin_id);
        }
    }
    Ok(())
}

/// Whether a session is currently running.
pub fn is_running(plugin_id: &str) -> Result<bool, String> {
    let sessions = SESSIONS.lock().map_err(|e| e.to_string())?;
    Ok(sessions.contains_key(plugin_id))
}

/// Call `render()` and return widget JSON.
pub fn render_plugin(plugin_id: &str) -> Result<String, String> {
    let sessions = SESSIONS.lock().map_err(|e| e.to_string())?;
    let lua = sessions
        .get(plugin_id)
        .ok_or_else(|| format!("plugin session not found: {plugin_id}"))?;
    call_render(lua)
}

/// Deliver a UI event JSON object to `on_event`, drain host intents, re-render.
pub fn plugin_on_event(
    plugin_id: &str,
    event_json: &str,
    fields_json: Option<&str>,
) -> Result<PluginResponse, String> {
    if let Some(fields) = fields_json {
        let trimmed = fields.trim();
        if !trimmed.is_empty() && trimmed != "null" {
            with_session(plugin_id, |lua| call_flush_state(lua, trimmed))?;
        }
    }
    let intents = with_session(plugin_id, |lua| call_handler(lua, "on_event", event_json))?;
    drain_host_and_render(plugin_id, &intents)
}

/// Capability / headless call: `dispatch(method, args)` in Lua.
pub fn call_plugin(
    plugin_id: &str,
    method: &str,
    args_json: &str,
) -> Result<String, String> {
    if !is_running(plugin_id)? {
        start_registered_plugin(plugin_id)?;
    }

    with_session(plugin_id, |lua| {
        let dispatch: Function = lua
            .globals()
            .get("dispatch")
            .map_err(|_| {
                "plugin must define dispatch(method, args) for capability calls".to_string()
            })?;

        let args: JsonValue = serde_json::from_str(if args_json.trim().is_empty() {
            "{}"
        } else {
            args_json
        })
        .map_err(|e| format!("invalid args JSON: {e}"))?;
        let lua_args = json_to_lua(lua, &args).map_err(|e| e.to_string())?;

        let result: Value = dispatch
            .call((method.to_string(), lua_args))
            .map_err(|e| format!("dispatch({method}) failed: {e}"))?;

        match result {
            Value::Nil => Ok("null".to_string()),
            Value::String(s) => {
                let text = s.to_string_lossy().to_owned();
                if text.trim_start().starts_with('{') || text.trim_start().starts_with('[') {
                    Ok(text)
                } else {
                    Ok(serde_json::to_string(&text).unwrap_or(text))
                }
            }
            other => {
                let json = crate::json_util::lua_to_json(other).map_err(|e| e.to_string())?;
                Ok(json.to_string())
            }
        }
    })
}

fn drain_host_and_render(
    plugin_id: &str,
    initial_intents_json: &str,
) -> Result<PluginResponse, String> {
    let mut provide_results = Vec::new();
    let mut pending = parse_intents(initial_intents_json)?;

    for _ in 0..16 {
        if pending.is_empty() {
            break;
        }

        let mut next_pending: Vec<JsonValue> = Vec::new();
        for intent in pending {
            match host::execute_intent(plugin_id, &intent)? {
                IntentOutcome::ProvideResult { value, ack } => {
                    provide_results.push(value);
                    let more = with_session(plugin_id, |lua| {
                        call_handler(lua, "on_host_result", &ack.to_string())
                    })?;
                    next_pending.extend(parse_intents(&more)?);
                }
                IntentOutcome::HostResult(result) => {
                    let more = with_session(plugin_id, |lua| {
                        call_handler(lua, "on_host_result", &result.to_string())
                    })?;
                    next_pending.extend(parse_intents(&more)?);
                }
            }
        }
        pending = next_pending;
    }

    let widget_json = render_plugin(plugin_id)?;
    Ok(PluginResponse {
        widget_json,
        provide_results,
    })
}

fn parse_intents(intents_json: &str) -> Result<Vec<JsonValue>, String> {
    let trimmed = intents_json.trim();
    if trimmed.is_empty() || trimmed == "null" {
        return Ok(vec![]);
    }
    let decoded: JsonValue =
        serde_json::from_str(trimmed).map_err(|e| format!("invalid intents JSON: {e}"))?;
    match decoded {
        JsonValue::Array(arr) => Ok(arr),
        JsonValue::Object(_) => Ok(vec![decoded]),
        _ => Ok(vec![]),
    }
}

fn with_session<T>(
    plugin_id: &str,
    f: impl FnOnce(&Lua) -> Result<T, String>,
) -> Result<T, String> {
    let sessions = SESSIONS.lock().map_err(|e| e.to_string())?;
    let lua = sessions
        .get(plugin_id)
        .ok_or_else(|| format!("plugin session not found: {plugin_id}"))?;
    f(lua)
}

fn call_render(lua: &Lua) -> Result<String, String> {
    let render: Function = lua
        .globals()
        .get("render")
        .map_err(|_| "plugin must define render()".to_string())?;
    let result: Value = render
        .call(())
        .map_err(|e| format!("render() failed: {e}"))?;
    value_to_widget_json(result)
}

fn call_flush_state(lua: &Lua, fields_json: &str) -> Result<(), String> {
    let Ok(flush) = lua.globals().get::<Function>("flush_state") else {
        return Ok(());
    };
    let payload: JsonValue = serde_json::from_str(fields_json)
        .map_err(|e| format!("invalid fields JSON: {e}"))?;
    let lua_payload = json_to_lua(lua, &payload).map_err(|e| e.to_string())?;
    flush
        .call::<()>(lua_payload)
        .map_err(|e| format!("flush_state() failed: {e}"))?;
    Ok(())
}

fn call_handler(lua: &Lua, name: &str, payload_json: &str) -> Result<String, String> {
    let Ok(handler) = lua.globals().get::<Function>(name) else {
        return Ok("[]".to_string());
    };

    let payload: JsonValue =
        serde_json::from_str(payload_json).map_err(|e| format!("invalid JSON payload: {e}"))?;
    let lua_payload = json_to_lua(lua, &payload).map_err(|e| e.to_string())?;

    let result: Value = handler
        .call(lua_payload)
        .map_err(|e| format!("{name}() failed: {e}"))?;
    value_to_intents_json(result).map_err(|e| e.to_string())
}
