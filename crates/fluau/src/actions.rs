//! Session-scoped UI action registry.
//!
//! Lua callback props may be a payload table **or** a function. Functions are
//! registered here during `render()` (staging → commit) and invoked when Flutter
//! dispatches a reserved `{ type = "action", id = "…" }` event.

use crate::json_util::{json_to_lua, lua_to_json, value_to_intents_json};
use mlua::{Function, Lua, Result as LuaResult, Table, Value};
use serde_json::{json, Map as JsonMap, Value as JsonValue};
use std::collections::HashMap;

/// Reserved event `type` for runtime-owned function callbacks.
pub const ACTION_EVENT_TYPE: &str = "action";

struct ActionRegistry {
    live: HashMap<String, mlua::RegistryKey>,
    staging: HashMap<String, mlua::RegistryKey>,
    next_id: u64,
    in_frame: bool,
}

impl ActionRegistry {
    fn new() -> Self {
        Self {
            live: HashMap::new(),
            staging: HashMap::new(),
            next_id: 0,
            in_frame: false,
        }
    }
}

/// Ensure an [`ActionRegistry`] is attached to this Lua VM.
pub fn ensure_registry(lua: &Lua) -> LuaResult<()> {
    if lua.app_data_ref::<ActionRegistry>().is_some() {
        return Ok(());
    }
    lua.set_app_data(ActionRegistry::new());
    Ok(())
}

/// Start a staging frame for a `render()` call.
pub fn begin_frame(lua: &Lua) -> Result<(), String> {
    ensure_registry(lua).map_err(|e| e.to_string())?;
    let mut reg = lua
        .app_data_mut::<ActionRegistry>()
        .ok_or_else(|| "action registry missing".to_string())?;
    reg.staging.clear();
    reg.in_frame = true;
    Ok(())
}

/// Commit staging handlers after a successful `render()` (drops previous live).
pub fn commit_frame(lua: &Lua) -> Result<(), String> {
    let mut reg = lua
        .app_data_mut::<ActionRegistry>()
        .ok_or_else(|| "action registry missing".to_string())?;
    if !reg.in_frame {
        return Ok(());
    }
    reg.live = std::mem::take(&mut reg.staging);
    reg.in_frame = false;
    Ok(())
}

/// Discard staging handlers after a failed `render()` (live unchanged).
pub fn discard_frame(lua: &Lua) {
    if let Some(mut reg) = lua.app_data_mut::<ActionRegistry>() {
        reg.staging.clear();
        reg.in_frame = false;
    }
}

fn register_function(lua: &Lua, func: Function) -> LuaResult<String> {
    ensure_registry(lua)?;
    let key = lua.create_registry_value(func)?;
    let mut reg = lua
        .app_data_mut::<ActionRegistry>()
        .ok_or_else(|| mlua::Error::runtime("action registry missing"))?;
    if !reg.in_frame {
        return Err(mlua::Error::runtime(
            "ui action/function callbacks are only valid during render()",
        ));
    }
    reg.next_id += 1;
    let id = format!("a{}", reg.next_id);
    reg.staging.insert(id.clone(), key);
    Ok(id)
}

/// Build the JSON payload for a registered action (`type` + `id` + extras).
pub fn action_payload(id: &str, extra: Option<JsonValue>) -> JsonValue {
    let mut map = JsonMap::new();
    map.insert("type".to_string(), json!(ACTION_EVENT_TYPE));
    map.insert("id".to_string(), json!(id));
    if let Some(JsonValue::Object(extra_map)) = extra {
        for (k, v) in extra_map {
            if k == "type" || k == "id" {
                continue;
            }
            map.insert(k, v);
        }
    }
    JsonValue::Object(map)
}

/// Encode a callback prop: Function → action payload; Table → JSON as-is.
pub fn callback_to_json(lua: &Lua, value: Value) -> LuaResult<JsonValue> {
    match value {
        Value::Function(func) => {
            let id = register_function(lua, func)?;
            Ok(action_payload(&id, None))
        }
        Value::Table(_) => lua_to_json(value),
        Value::Nil => Ok(JsonValue::Null),
        other => Err(mlua::Error::runtime(format!(
            "callback prop must be a table or function, got {}",
            other.type_name()
        ))),
    }
}

/// `ui.action(fn, extra?)` → Lua table payload `{ type = "action", id, … }`.
pub fn ui_action(lua: &Lua, func: Function, extra: Option<Table>) -> LuaResult<Table> {
    let id = register_function(lua, func)?;
    let extra_json = match extra {
        Some(t) => Some(lua_to_json(Value::Table(t))?),
        None => None,
    };
    let payload = action_payload(&id, extra_json);
    match json_to_lua(lua, &payload)? {
        Value::Table(t) => Ok(t),
        _ => Err(mlua::Error::runtime("action payload must be a table")),
    }
}

/// Install `ui.action` on the existing `ui` global table.
pub fn install_ui_helpers(lua: &Lua) -> LuaResult<()> {
    ensure_registry(lua)?;
    let ui: Table = match lua.globals().get("ui") {
        Ok(t) => t,
        Err(_) => {
            let t = lua.create_table()?;
            lua.globals().set("ui", t.clone())?;
            t
        }
    };
    ui.set(
        "action",
        lua.create_function(|lua, (func, extra): (Function, Option<Table>)| {
            ui_action(lua, func, extra)
        })?,
    )?;
    Ok(())
}

/// Invoke a reserved `action` event; returns intents JSON when handled.
pub fn try_invoke_action(lua: &Lua, event: &JsonValue) -> Result<Option<String>, String> {
    let typ = event.get("type").and_then(|v| v.as_str());
    if typ != Some(ACTION_EVENT_TYPE) {
        return Ok(None);
    }
    let id = event
        .get("id")
        .and_then(|v| v.as_str())
        .ok_or_else(|| "action event missing string id".to_string())?;

    let func = {
        let reg = lua
            .app_data_ref::<ActionRegistry>()
            .ok_or_else(|| "action registry missing".to_string())?;
        let key = reg
            .live
            .get(id)
            .ok_or_else(|| format!("unknown action id '{id}'"))?;
        lua.registry_value::<Function>(key)
            .map_err(|e| format!("action registry lookup failed: {e}"))?
    };

    let lua_event = json_to_lua(lua, event).map_err(|e| e.to_string())?;
    let result: Value = func
        .call(lua_event)
        .map_err(|e| format!("action handler failed: {e}"))?;
    let intents = value_to_intents_json(result).map_err(|e| e.to_string())?;
    Ok(Some(intents))
}

#[cfg(test)]
mod tests {
    use super::*;
    use mlua::Lua;

    #[test]
    fn staging_commit_replaces_live_handlers() {
        let lua = Lua::new();
        ensure_registry(&lua).unwrap();
        begin_frame(&lua).unwrap();
        let f1 = lua.create_function(|_, ()| Ok(())).unwrap();
        let id1 = register_function(&lua, f1).unwrap();
        commit_frame(&lua).unwrap();

        begin_frame(&lua).unwrap();
        let f2 = lua.create_function(|_, ()| Ok(())).unwrap();
        let id2 = register_function(&lua, f2).unwrap();
        assert_ne!(id1, id2);
        commit_frame(&lua).unwrap();

        let event = json!({ "type": "action", "id": id1 });
        let err = try_invoke_action(&lua, &event).expect_err("old id should be gone");
        assert!(err.contains("unknown action"), "{err}");

        let event2 = json!({ "type": "action", "id": id2 });
        let intents = try_invoke_action(&lua, &event2).unwrap();
        assert_eq!(intents.as_deref(), Some("[]"));
    }

    #[test]
    fn discard_keeps_live_handlers() {
        let lua = Lua::new();
        ensure_registry(&lua).unwrap();
        begin_frame(&lua).unwrap();
        let f1 = lua.create_function(|_, ()| Ok(42)).unwrap();
        let id1 = register_function(&lua, f1).unwrap();
        commit_frame(&lua).unwrap();

        begin_frame(&lua).unwrap();
        let f2 = lua.create_function(|_, ()| Ok(())).unwrap();
        let _ = register_function(&lua, f2).unwrap();
        discard_frame(&lua);

        let event = json!({ "type": "action", "id": id1 });
        let intents = try_invoke_action(&lua, &event).unwrap();
        assert!(intents.is_some());
    }
}
