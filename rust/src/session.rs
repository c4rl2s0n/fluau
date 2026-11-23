//! Persistent Luau plugin sessions (sandboxed).
//!
//! Each plugin id owns one long-lived Lua VM. UI is produced by `render()`,
//! interactions arrive as JSON events via `on_event`. Host intents (`db` /
//! `http` / `app.provideResult`) are drained on the Rust host layer.

use crate::host::{self, IntentOutcome};
use crate::json_util::{
    json_to_lua, value_to_intents_json, value_to_widget_json,
};
use crate::lua_engine;
use crate::registry;
use lazy_static::lazy_static;
use mlua::{Function, Lua, Value};
use serde_json::Value as JsonValue;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};

lazy_static! {
    static ref SESSIONS: Mutex<HashMap<String, Lua>> = Mutex::new(HashMap::new());
}

/// Result of running a plugin entrypoint that may request host work.
#[derive(Clone, Debug)]
pub(crate) struct PluginResponse {
    pub widget_json: String,
    /// Values from `app.provideResult` intents collected while draining.
    pub provide_results: Vec<String>,
}

/// Create (or replace) a plugin session and load its script.
pub(crate) fn start_plugin(plugin_id: &str, script: &str) -> Result<(), String> {
    start_plugin_with_modules(plugin_id, script, HashMap::new(), None)
}

fn start_plugin_with_modules(
    plugin_id: &str,
    script: &str,
    modules: HashMap<String, String>,
    permissions: Option<registry::PluginPermissions>,
) -> Result<(), String> {
    let perms = permissions.unwrap_or(registry::PluginPermissions {
        host: vec!["http.request".into(), "db".into()],
        http_allowlist: vec!["fake.proton".into()],
        libraries: vec![],
    });

    let lua = Lua::new();
    lua_engine::setup_lua_api(&lua).map_err(|e| e.to_string())?;
    inject_require(&lua, plugin_id, modules, &perms.libraries).map_err(|e| e.to_string())?;
    inject_host_api(&lua, plugin_id, &perms).map_err(|e| e.to_string())?;

    // Luau sandbox: libs/globals read-only; local env for script writes.
    lua.sandbox(true).map_err(|e| format!("sandbox enable failed: {e}"))?;

    crate::host::http_client::configure(plugin_id, perms.http_allowlist.clone())?;

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

fn host_allowed(perms: &registry::PluginPermissions, name: &str) -> bool {
    perms.host.iter().any(|h| {
        h == name
            || (h == "http.request" && name == "http")
            || (name == "crypto" && (h == "crypto" || h.starts_with("crypto.")))
            || (name == "log" && (h == "log" || h == "logging"))
    })
}

fn inject_require(
    lua: &Lua,
    plugin_id: &str,
    modules: HashMap<String, String>,
    library_perms: &[String],
) -> mlua::Result<()> {
    let modules = Arc::new(modules);
    let loaded: Arc<Mutex<HashMap<String, Value>>> = Arc::new(Mutex::new(HashMap::new()));
    let pid = plugin_id.to_string();
    let libs: Vec<String> = library_perms.to_vec();

    let require_fn = lua.create_function(move |lua, name: String| {
        // Permission check (empty libs ⇒ allow package modules).
        let allowed = if libs.is_empty() {
            true
        } else {
            registry::library_allowed(&pid, &name).unwrap_or(false)
                || libs.iter().any(|l| l == &name || l == &format!("plugin:{name}"))
        };
        if !allowed {
            return Err(mlua::Error::runtime(format!(
                "require('{name}') not allowed by plugin permissions.libraries"
            )));
        }

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

/// Sync host helpers available to Lua (db + http + optional crypto), gated by permissions.
fn inject_host_api(
    lua: &Lua,
    plugin_id: &str,
    perms: &registry::PluginPermissions,
) -> mlua::Result<()> {
    use crate::host::crypto_api::HostCrypto;
    use crate::host::db_api::HostDb;
    use crate::host::http_api::HostHttp;
    use crate::host::log_api::HostLog;
    use crate::host::Host;

    let host = Host::new(plugin_id);
    let root = lua.create_table()?;

    // Permissions still gate which modules appear; stubs describe the full surface.
    if perms.host.iter().any(|h| h == "db") {
        HostDb::install_into(&root, host.clone(), lua)?;
    }
    if host_allowed(perms, "http") || perms.host.iter().any(|h| h == "http.request") {
        HostHttp::install_into(&root, host.clone(), lua)?;
    }
    if host_allowed(perms, "crypto") {
        HostCrypto::install_into(&root, host.clone(), lua)?;
    }
    if host_allowed(perms, "log") {
        HostLog::install_into(&root, host.clone(), lua)?;
    }

    lua.globals().set("host", root)?;
    Ok(())
}

/// Start a session from a registered plugin id.
pub(crate) fn start_registered_plugin(plugin_id: &str) -> Result<(), String> {
    let script = registry::get_script(plugin_id)?;
    let modules = registry::get_modules(plugin_id)?;
    let manifest = registry::get_plugin(plugin_id)?;
    start_plugin_with_modules(plugin_id, &script, modules, Some(manifest.permissions))
}

/// Drop a plugin session.
pub(crate) fn stop_plugin(plugin_id: &str) -> Result<(), String> {
    let mut sessions = SESSIONS.lock().map_err(|e| e.to_string())?;
    sessions.remove(plugin_id);
    crate::host::http_client::clear_client(plugin_id);
    Ok(())
}

/// Whether a session is currently running.
pub(crate) fn is_running(plugin_id: &str) -> Result<bool, String> {
    let sessions = SESSIONS.lock().map_err(|e| e.to_string())?;
    Ok(sessions.contains_key(plugin_id))
}

/// Call `render()` and return widget JSON.
pub(crate) fn render_plugin(plugin_id: &str) -> Result<String, String> {
    let sessions = SESSIONS.lock().map_err(|e| e.to_string())?;
    let lua = sessions
        .get(plugin_id)
        .ok_or_else(|| format!("plugin session not found: {plugin_id}"))?;
    call_render(lua)
}

/// Deliver a UI event JSON object to `on_event`, drain host intents, re-render.
pub(crate) fn plugin_on_event(
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
pub(crate) fn call_plugin(
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

#[cfg(test)]
#[path = "srp_golden.rs"]
mod srp_golden;

#[cfg(test)]
mod tests {
    use super::*;

    const SCRIPT: &str = r#"
state = { n = 0, label = "Hi", selected = nil }
function render()
  return ui.Text { text = state.label .. ":" .. tostring(state.n) }
end
function on_event(event)
  if event.type == "inc" then
    state.n = state.n + 1
    state.label = "Clicked"
  end
  return {}
end
function dispatch(method, args)
  if method == "get_selected_config" then
    return { ok = false, error = "none" }
  end
  return { ok = false, error = "unknown" }
end
"#;

    #[test]
    fn session_persists_across_events() {
        start_plugin("t1", SCRIPT).unwrap();
        let first = render_plugin("t1").unwrap();
        assert!(first.contains("Hi:0"), "{first}");

        let resp = plugin_on_event("t1", r#"{"type":"inc"}"#, None).unwrap();
        assert!(resp.widget_json.contains("Clicked:1"), "{}", resp.widget_json);

        let second = render_plugin("t1").unwrap();
        assert!(second.contains("Clicked:1"), "{second}");
        stop_plugin("t1").unwrap();
    }

    #[test]
    fn call_plugin_dispatch() {
        start_plugin("t2", SCRIPT).unwrap();
        let result = call_plugin("t2", "get_selected_config", "{}").unwrap();
        assert!(result.contains("none") || result.contains("ok"), "{result}");
        stop_plugin("t2").unwrap();
    }

    #[test]
    fn rust_host_drains_db_and_provide_result() {
        let script = r#"
state = { v = nil }
function render()
  return ui.Text { text = tostring(state.v or "nil") }
end
function on_event(event)
  if event.type == "save" then
    return {
      { type = "db.set", requestId = "s", key = "k", value = "hello" },
      { type = "app.provideResult", requestId = "p", value = "handed-off" },
    }
  end
  return {}
end
function on_host_result(result)
  if result.type == "db.set" then
    state.v = host.db.get("k")
  end
  return {}
end
function dispatch(method, args)
  return { value = host.db.get("k") }
end
"#;
        start_plugin("t3", script).unwrap();
        let resp = plugin_on_event("t3", r#"{"type":"save"}"#, None).unwrap();
        assert!(
            resp.provide_results.iter().any(|s| s == "handed-off"),
            "{:?}",
            resp.provide_results
        );
        assert!(resp.widget_json.contains("hello"), "{}", resp.widget_json);
        let via_dispatch = call_plugin("t3", "any", "{}").unwrap();
        assert!(via_dispatch.contains("hello"), "{via_dispatch}");
        stop_plugin("t3").unwrap();
    }

    #[test]
    fn flush_state_then_login_shows_servers() {
        let script = r#"
state = { screen = "login", user = "", pass = "", servers = {}, error = nil }
function flush_state(fields)
  if fields.user ~= nil then state.user = fields.user end
  if fields.pass ~= nil then state.pass = fields.pass end
end
function render()
  if state.screen == "servers" then
    local kids = { ui.Text { text = "Select a server" } }
    for _, s in ipairs(state.servers) do
      table.insert(kids, ui.Button { text = s.id, onPressed = { type = "selectServer", id = s.id } })
    end
    return ui.Column { children = kids }
  end
  return ui.Text { text = "login:" .. tostring(state.user) }
end
function on_event(event)
  if event.type == "login" then
    if state.user == nil or state.user == "" then
      state.error = "Username is required"
      return {}
    end
    local auth = host.http.request({
      method = "POST",
      url = "https://fake.proton/auth/login",
      body = { username = state.user, password = state.pass },
    })
    if not auth.ok then
      state.error = "Login failed"
      return {}
    end
    local list = host.http.request({
      method = "GET",
      url = "https://fake.proton/vpn/servers",
    })
    state.servers = list.body.servers or {}
    state.screen = "servers"
    return {}
  end
  return {}
end
"#;
        start_plugin("t4", script).unwrap();
        let resp = plugin_on_event(
            "t4",
            r#"{"type":"login"}"#,
            Some(r#"{"user":"alice","pass":"x"}"#),
        )
        .unwrap();
        assert!(
            resp.widget_json.contains("CH#12"),
            "expected servers in UI, got: {}",
            resp.widget_json
        );
        stop_plugin("t4").unwrap();
    }

    #[test]
    fn require_loads_vendored_module() {
        let mut modules = HashMap::new();
        modules.insert(
            "greet".into(),
            "return { hello = function(n) return 'hi '..n end }".into(),
        );
        start_plugin_with_modules(
            "t5",
            r#"
local greet = require("greet")
state = { msg = greet.hello("bob") }
function render()
  return ui.Text { text = state.msg }
end
function on_event(event) return {} end
"#,
            modules,
            Some(registry::PluginPermissions {
                host: vec!["db".into()],
                http_allowlist: vec![],
                libraries: vec!["plugin:greet".into()],
            }),
        )
        .unwrap();
        let ui = render_plugin("t5").unwrap();
        assert!(ui.contains("hi bob"), "{ui}");
        stop_plugin("t5").unwrap();
    }

    #[test]
    fn host_log_permission_writes() {
        start_plugin_with_modules(
            "t-log",
            r#"
state = { ok = false }
function init()
  host.log.info("hello-from-plugin")
  state.ok = true
end
function render()
  return ui.Text { text = state.ok and "ok:log" or "fail" }
end
function on_event(event) return {} end
"#,
            HashMap::new(),
            Some(registry::PluginPermissions {
                host: vec!["log".into()],
                http_allowlist: vec![],
                libraries: vec![],
            }),
        )
        .unwrap();
        let ui = render_plugin("t-log").unwrap();
        assert!(ui.contains("ok:log"), "{ui}");
        stop_plugin("t-log").unwrap();
    }

    #[test]
    fn lua_srp_generate_proofs_smoke() {
        // Uses go-srp published test modulus/ephemeral (MIT). Random client secret
        // means proofs won't match golden vectors, but generation must succeed.
        let bytes_src = include_str!("../../assets/plugins/proton_vpn/lib/bytes.lua");
        let bigint_src = include_str!("../../assets/plugins/proton_vpn/lib/bigint.lua");
        let pmhash_src = include_str!("../../assets/plugins/proton_vpn/lib/pmhash.lua");
        let srp_src = include_str!("../../assets/plugins/proton_vpn/lib/proton_srp.lua");

        let mut modules = HashMap::new();
        modules.insert("bytes".into(), bytes_src.into());
        modules.insert("bigint".into(), bigint_src.into());
        modules.insert("pmhash".into(), pmhash_src.into());
        modules.insert("proton_srp".into(), srp_src.into());

        let script = r#"
local srp = require("proton_srp")
local modulus = [[-----BEGIN PGP SIGNED MESSAGE-----
Hash: SHA256

W2z5HBi8RvsfYzZTS7qBaUxxPhsfHJFZpu3Kd6s1JafNrCCH9rfvPLrfuqocxWPgWDH2R8neK7PkNvjxto9TStuY5z7jAzWRvFWN9cQhAKkdWgy0JY6ywVn22+HFpF4cYesHrqFIKUPDMSSIlWjBVmEJZ/MusD44ZT29xcPrOqeZvwtCffKtGAIjLYPZIEbZKnDM1Dm3q2K/xS5h+xdhjnndhsrkwm9U9oyA2wxzSXFL+pdfj2fOdRwuR5nW0J2NFrq3kJjkRmpO/Genq1UW+TEknIWAb6VzJJJA244K/H8cnSx2+nSNZO3bbo6Ys228ruV9A8m6DhxmS+bihN3ttQ==
-----BEGIN PGP SIGNATURE-----
Version: ProtonMail

wl4EARYIABAFAlwB1j0JEDUFhcTpUY8mAAD8CgEAnsFnF4cF0uSHKkXa1GIa
GO86yMV4zDZEZcDSJo0fgr8A/AlupGN9EdHlsrZLmTA1vhIx+rOgxdEff28N
kvNM7qIK
=q6vu
-----END PGP SIGNATURE-----]]
local serverEphemeral = "l13IQSVFBEV0ZZREuRQ4ZgP6OpGiIfIjbSDYQG3Yp39FkT2B/k3n1ZhwqrAdy+qvPPFq/le0b7UDtayoX4aOTJihoRvifas8Hr3icd9nAHqd0TUBbkZkT6Iy6UpzmirCXQtEhvGQIdOLuwvy+vZWh24G2ahBM75dAqwkP961EJMh67/I5PA5hJdQZjdPT5luCyVa7BS1d9ZdmuR0/VCjUOdJbYjgtIH7BQoZs+KacjhUN8gybu+fsycvTK3eC+9mCN2Y6GdsuCMuR3pFB0RF9eKae7cA6RbJfF1bjm0nNfWLXzgKguKBOeF3GEAsnCgK68q82/pq9etiUDizUlUBcA=="
state = { err = nil, ok = false }
local proofs, err = srp.generate_proofs({
  version = 4,
  username = "jakubqa",
  password = "abc123",
  salt = "yKlc5/CvObfoiw==",
  modulus = modulus,
  serverEphemeral = serverEphemeral,
})
if proofs then
  state.ok = proofs.clientProof ~= nil and proofs.clientEphemeral ~= nil
else
  state.err = tostring(err)
end
function render()
  if state.ok then
    return ui.Text { text = "srp-ok" }
  end
  return ui.Text { text = "srp-err:" .. tostring(state.err) }
end
function on_event(event) return {} end
"#;

        start_plugin_with_modules(
            "t6-srp",
            script,
            modules,
            Some(registry::PluginPermissions {
                host: vec!["crypto".into()],
                http_allowlist: vec![],
                libraries: vec![
                    "plugin:bytes".into(),
                    "plugin:bigint".into(),
                    "plugin:pmhash".into(),
                    "plugin:proton_srp".into(),
                ],
            }),
        )
        .unwrap();
        let ui = render_plugin("t6-srp").unwrap();
        assert!(
            ui.contains("srp-ok"),
            "expected Luau SRP proofs, got: {ui}"
        );
        stop_plugin("t6-srp").unwrap();
    }
}
