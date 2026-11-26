//! Persistent Luau plugin sessions (sandboxed).
//!
//! Each plugin id owns one long-lived Lua VM. UI is produced by `render()`,
//! interactions arrive as JSON events via `on_event`. Host intents (`db` /
//! `http` / `app.provideResult`) are drained on the Rust host layer.

use crate::diagnostic::{self, plugin_err, PluginOpGuard};
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
    diagnostic::install_diagnostic_hooks();
    let _op = PluginOpGuard::enter(plugin_id, "start");

    let session_grants = registry::resolve_session_grants(&permissions, &grants)
        .map_err(|e| plugin_err(plugin_id, "start", e))?;

    PermissionGate::clear(plugin_id);
    PermissionGate::bind(plugin_id, session_grants.clone())
        .map_err(|e| plugin_err(plugin_id, "start", e))?;

    if let Ok(slot) = SESSION_PREPARE.lock() {
        if let Some(prepare) = *slot {
            prepare(plugin_id, &session_grants)
                .map_err(|e| plugin_err(plugin_id, "session_prepare", e))?;
        }
    }

    let granted_apis: Vec<String> = session_grants.host.keys().cloned().collect();

    let lua = Lua::new();
    ui::install_ui(&lua).map_err(|e| plugin_err(plugin_id, "install_ui", e))?;
    inject_require(&lua, plugin_id, modules)
        .map_err(|e| plugin_err(plugin_id, "inject_require", e))?;
    let host = host::Host::new(plugin_id);
    api_registry::inject_granted(&lua, host, &granted_apis)
        .map_err(|e| plugin_err(plugin_id, "inject_host_apis", e))?;

    // Luau sandbox: libs/globals read-only; local env for script writes.
    lua.sandbox(true)
        .map_err(|e| plugin_err(plugin_id, "sandbox", e))?;

    lua.load(script)
        .set_name(&format!("@{plugin_id}"))
        .exec()
        .map_err(|e| plugin_err(plugin_id, "load_script", e))?;

    if let Ok(init) = lua.globals().get::<Function>("init") {
        init.call::<()>(())
            .map_err(|e| plugin_err(plugin_id, "init", e))?;
    }

    let mut sessions = SESSIONS.lock().map_err(|e| plugin_err(plugin_id, "sessions", e))?;
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
    let script = registry::get_script(plugin_id)
        .map_err(|e| plugin_err(plugin_id, "start_registered", e))?;
    let modules = registry::get_modules(plugin_id)
        .map_err(|e| plugin_err(plugin_id, "start_registered", e))?;
    let manifest = registry::get_plugin(plugin_id)
        .map_err(|e| plugin_err(plugin_id, "start_registered", e))?;
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
    let manifest = registry::get_plugin(plugin_id)
        .map_err(|e| plugin_err(plugin_id, "start_registered", e))?;
    let grants = PluginGrants::all_requested(&manifest.permissions);
    start_registered_plugin_with_grants(plugin_id, grants)
}

/// Drop a plugin session.
pub fn stop_plugin(plugin_id: &str) -> Result<(), String> {
    diagnostic::install_diagnostic_hooks();
    let _op = PluginOpGuard::enter(plugin_id, "stop");
    let mut sessions = SESSIONS.lock().map_err(|e| plugin_err(plugin_id, "stop", e))?;
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
    diagnostic::install_diagnostic_hooks();
    let _op = PluginOpGuard::enter(plugin_id, "render");
    with_session(plugin_id, |lua| call_render(plugin_id, lua))
}

/// Deliver a UI event JSON object to `on_event` (or a reserved `action`), drain
/// host intents, re-render.
pub fn plugin_on_event(
    plugin_id: &str,
    event_json: &str,
    fields_json: Option<&str>,
) -> Result<PluginResponse, String> {
    diagnostic::install_diagnostic_hooks();
    let _op = PluginOpGuard::enter(plugin_id, "on_event");
    if let Some(fields) = fields_json {
        let trimmed = fields.trim();
        if !trimmed.is_empty() && trimmed != "null" {
            with_session(plugin_id, |lua| call_flush_state(plugin_id, lua, trimmed))?;
        }
    }

    let event: JsonValue = serde_json::from_str(event_json).map_err(|e| {
        plugin_err(
            plugin_id,
            "on_event",
            format!("invalid event JSON: {e}"),
        )
    })?;

    let intents = with_session(plugin_id, |lua| {
        if let Some(action_intents) = crate::actions::try_invoke_action(lua, &event)
            .map_err(|e| plugin_err(plugin_id, "action", e))?
        {
            return Ok(action_intents);
        }
        call_handler(plugin_id, lua, "on_event", event_json)
    })?;
    drain_host_and_render(plugin_id, &intents)
}

/// Capability / headless call: `dispatch(method, args)` in Lua.
pub fn call_plugin(
    plugin_id: &str,
    method: &str,
    args_json: &str,
) -> Result<String, String> {
    diagnostic::install_diagnostic_hooks();
    let _op = PluginOpGuard::enter(plugin_id, &format!("dispatch({method})"));
    if !is_running(plugin_id)? {
        start_registered_plugin(plugin_id)?;
    }

    with_session(plugin_id, |lua| {
        let dispatch: Function = lua.globals().get("dispatch").map_err(|_| {
            plugin_err(
                plugin_id,
                "dispatch",
                "plugin must define dispatch(method, args) for capability calls",
            )
        })?;

        let args: JsonValue = serde_json::from_str(if args_json.trim().is_empty() {
            "{}"
        } else {
            args_json
        })
        .map_err(|e| plugin_err(plugin_id, "dispatch", format!("invalid args JSON: {e}")))?;
        let lua_args = json_to_lua(lua, &args)
            .map_err(|e| plugin_err(plugin_id, "dispatch", e))?;

        let result: Value = dispatch
            .call((method.to_string(), lua_args))
            .map_err(|e| plugin_err(plugin_id, &format!("dispatch({method})"), e))?;

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
                let json = crate::json_util::lua_to_json(other)
                    .map_err(|e| plugin_err(plugin_id, "dispatch", e))?;
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
    let mut pending = parse_intents(plugin_id, initial_intents_json)?;

    for _ in 0..16 {
        if pending.is_empty() {
            break;
        }

        let mut next_pending: Vec<JsonValue> = Vec::new();
        for intent in pending {
            match host::execute_intent(plugin_id, &intent)
                .map_err(|e| plugin_err(plugin_id, "host_intent", e))?
            {
                IntentOutcome::ProvideResult { value, ack } => {
                    provide_results.push(value);
                    let more = with_session(plugin_id, |lua| {
                        call_handler(plugin_id, lua, "on_host_result", &ack.to_string())
                    })?;
                    next_pending.extend(parse_intents(plugin_id, &more)?);
                }
                IntentOutcome::HostResult(result) => {
                    let more = with_session(plugin_id, |lua| {
                        call_handler(plugin_id, lua, "on_host_result", &result.to_string())
                    })?;
                    next_pending.extend(parse_intents(plugin_id, &more)?);
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

fn parse_intents(plugin_id: &str, intents_json: &str) -> Result<Vec<JsonValue>, String> {
    let trimmed = intents_json.trim();
    if trimmed.is_empty() || trimmed == "null" {
        return Ok(vec![]);
    }
    let decoded: JsonValue = serde_json::from_str(trimmed)
        .map_err(|e| plugin_err(plugin_id, "parse_intents", format!("invalid intents JSON: {e}")))?;
    match decoded {
        JsonValue::Array(arr) => Ok(arr),
        JsonValue::Object(_) => Ok(vec![decoded]),
        _ => Ok(vec![]),
    }
}

/// Clone the session `Lua` handle under a short lock, then run `f` without holding `SESSIONS`.
fn with_session<T>(
    plugin_id: &str,
    f: impl FnOnce(&Lua) -> Result<T, String>,
) -> Result<T, String> {
    let lua = {
        let sessions = SESSIONS
            .lock()
            .map_err(|e| plugin_err(plugin_id, "sessions", e))?;
        sessions
            .get(plugin_id)
            .cloned()
            .ok_or_else(|| plugin_err(plugin_id, "sessions", "plugin session not found"))?
    };
    f(&lua)
}

fn call_render(plugin_id: &str, lua: &Lua) -> Result<String, String> {
    crate::actions::begin_frame(lua)
        .map_err(|e| plugin_err(plugin_id, "render", e))?;

    let render: Function = match lua.globals().get("render") {
        Ok(f) => f,
        Err(_) => {
            crate::actions::discard_frame(lua);
            return Err(plugin_err(
                plugin_id,
                "render",
                "plugin must define render()",
            ));
        }
    };

    let result: Value = match render.call(()) {
        Ok(v) => v,
        Err(e) => {
            crate::actions::discard_frame(lua);
            return Err(plugin_err(plugin_id, "render", e));
        }
    };

    let widget_json = match value_to_widget_json(result) {
        Ok(j) => j,
        Err(e) => {
            crate::actions::discard_frame(lua);
            return Err(plugin_err(plugin_id, "render", e));
        }
    };

    crate::actions::commit_frame(lua)
        .map_err(|e| plugin_err(plugin_id, "render", e))?;
    Ok(widget_json)
}

fn call_flush_state(plugin_id: &str, lua: &Lua, fields_json: &str) -> Result<(), String> {
    let Ok(flush) = lua.globals().get::<Function>("flush_state") else {
        return Ok(());
    };
    let payload: JsonValue = serde_json::from_str(fields_json)
        .map_err(|e| plugin_err(plugin_id, "flush_state", format!("invalid fields JSON: {e}")))?;
    let lua_payload =
        json_to_lua(lua, &payload).map_err(|e| plugin_err(plugin_id, "flush_state", e))?;
    flush
        .call::<()>(lua_payload)
        .map_err(|e| plugin_err(plugin_id, "flush_state", e))?;
    Ok(())
}

fn call_handler(
    plugin_id: &str,
    lua: &Lua,
    name: &str,
    payload_json: &str,
) -> Result<String, String> {
    let Ok(handler) = lua.globals().get::<Function>(name) else {
        return Ok("[]".to_string());
    };

    let payload: JsonValue = serde_json::from_str(payload_json).map_err(|e| {
        plugin_err(
            plugin_id,
            name,
            format!("invalid JSON payload: {e}"),
        )
    })?;
    let lua_payload =
        json_to_lua(lua, &payload).map_err(|e| plugin_err(plugin_id, name, e))?;

    let result: Value = handler
        .call(lua_payload)
        .map_err(|e| plugin_err(plugin_id, name, e))?;
    value_to_intents_json(result).map_err(|e| plugin_err(plugin_id, name, e))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::registry::{PluginGrants, PluginPermissions};

    #[test]
    fn plugin_err_includes_id_and_op() {
        let msg = plugin_err("hello", "render", "boom");
        assert!(msg.contains("[hello]"));
        assert!(msg.contains("render"));
        assert!(msg.contains("boom"));
    }

    #[test]
    fn render_error_includes_plugin_id_and_message() {
        diagnostic::install_diagnostic_hooks();
        let id = "err_plugin";
        let script = r#"
            function render()
                error("intentional failure")
            end
        "#;
        start_plugin(
            id,
            script,
            PluginPermissions::default(),
            PluginGrants::default(),
        )
        .expect("start");
        let err = render_plugin(id).expect_err("render should fail");
        assert!(err.contains("[err_plugin]"), "{err}");
        assert!(err.contains("render"), "{err}");
        assert!(err.contains("intentional failure"), "{err}");
        let _ = stop_plugin(id);
    }

    #[test]
    fn reserved_action_event_invokes_handler_without_on_event() {
        diagnostic::install_diagnostic_hooks();
        let id = "action_plugin";
        let script = r#"
            local count = 0
            function render()
                ui.action(function()
                    count = count + 1
                end)
                return '{"type":"Text","text":"' .. tostring(count) .. '"}'
            end
        "#;
        start_plugin(
            id,
            script,
            PluginPermissions::default(),
            PluginGrants::default(),
        )
        .expect("start");
        let first = render_plugin(id).expect("render");
        assert!(first.contains("\"text\":\"0\""), "{first}");

        let resp = plugin_on_event(id, r#"{"type":"action","id":"a1"}"#, None)
            .expect("action event");
        assert!(
            resp.widget_json.contains("\"text\":\"1\""),
            "{}",
            resp.widget_json
        );
        let _ = stop_plugin(id);
    }
}
