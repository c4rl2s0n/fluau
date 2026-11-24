//! Helpers to convert between Lua values and JSON.

use mlua::{Lua, Result as LuaResult, Table, Value};
use serde_json::{Map as JsonMap, Number, Value as JsonValue};

/// Convert a serde_json value into an owned Lua value.
pub fn json_to_lua(lua: &Lua, value: &JsonValue) -> LuaResult<Value> {
    match value {
        JsonValue::Null => Ok(Value::Nil),
        JsonValue::Bool(b) => Ok(Value::Boolean(*b)),
        JsonValue::Number(n) => {
            // Luau uses i32 for Integer; fall back to Number for larger values.
            if let Some(i) = n.as_i64() {
                if let Ok(small) = i32::try_from(i) {
                    Ok(Value::Integer(small))
                } else {
                    Ok(Value::Number(i as f64))
                }
            } else if let Some(f) = n.as_f64() {
                Ok(Value::Number(f))
            } else {
                Ok(Value::Nil)
            }
        }
        JsonValue::String(s) => Ok(Value::String(lua.create_string(s)?)),
        JsonValue::Array(arr) => {
            let table = lua.create_table_with_capacity(arr.len(), 0)?;
            for (i, item) in arr.iter().enumerate() {
                table.set(i + 1, json_to_lua(lua, item)?)?;
            }
            Ok(Value::Table(table))
        }
        JsonValue::Object(obj) => {
            let table = lua.create_table_with_capacity(0, obj.len())?;
            for (k, v) in obj {
                table.set(k.as_str(), json_to_lua(lua, v)?)?;
            }
            Ok(Value::Table(table))
        }
    }
}

/// Convert a Lua value into JSON.
pub fn lua_to_json(value: Value) -> LuaResult<JsonValue> {
    match value {
        Value::Nil => Ok(JsonValue::Null),
        Value::Boolean(b) => Ok(JsonValue::Bool(b)),
        Value::Integer(i) => Ok(JsonValue::Number(Number::from(i))),
        Value::Number(n) => Ok(Number::from_f64(n)
            .map(JsonValue::Number)
            .unwrap_or(JsonValue::Null)),
        Value::String(s) => Ok(JsonValue::String(s.to_string_lossy().to_owned())),
        Value::Table(table) => lua_table_to_json(table),
        _ => Err(mlua::Error::runtime(
            "unsupported Lua value for JSON conversion",
        )),
    }
}

fn lua_array_index(key: &Value) -> Option<usize> {
    match key {
        Value::Integer(i) if *i >= 1 => Some(*i as usize),
        Value::Number(n) if n.is_finite() && *n >= 1.0 && n.fract() == 0.0 => {
            Some(*n as usize)
        }
        _ => None,
    }
}

fn lua_table_to_json(table: Table) -> LuaResult<JsonValue> {
    // Detect array-like tables (consecutive integer keys starting at 1).
    // Accept both Integer and whole Number keys (mlua may yield either).
    let mut max_index = 0usize;
    let mut is_array = true;
    let mut pair_count = 0usize;

    for pair in table.pairs::<Value, Value>() {
        let (key, _) = pair?;
        pair_count += 1;
        if let Some(i) = lua_array_index(&key) {
            max_index = max_index.max(i);
        } else {
            is_array = false;
        }
    }

    if is_array && pair_count > 0 && max_index == pair_count {
        let mut arr = Vec::with_capacity(max_index);
        for i in 1..=max_index {
            let v: Value = table.get(i)?;
            arr.push(lua_to_json(v)?);
        }
        return Ok(JsonValue::Array(arr));
    }

    let mut map = JsonMap::new();
    for pair in table.pairs::<Value, Value>() {
        let (key, value) = pair?;
        let key_str = match key {
            Value::String(s) => s.to_string_lossy().to_owned(),
            Value::Integer(i) => i.to_string(),
            Value::Number(n) => n.to_string(),
            _ => continue,
        };
        map.insert(key_str, lua_to_json(value)?);
    }
    Ok(JsonValue::Object(map))
}

/// Normalize a Lua return value into an intents JSON array string.
pub fn value_to_intents_json(value: Value) -> LuaResult<String> {
    match value {
        Value::Nil => Ok("[]".to_string()),
        Value::String(s) => {
            let text = s.to_string_lossy();
            // Allow already-encoded JSON arrays/objects.
            if text.trim_start().starts_with('[') || text.trim_start().starts_with('{') {
                Ok(text.to_owned())
            } else {
                Ok("[]".to_string())
            }
        }
        other => {
            let json = lua_to_json(other)?;
            match json {
                JsonValue::Array(_) => Ok(json.to_string()),
                JsonValue::Object(_) => Ok(serde_json::Value::Array(vec![json]).to_string()),
                _ => Ok("[]".to_string()),
            }
        }
    }
}

/// Extract widget JSON string from a Lua return value (widget constructors return JSON strings).
pub fn value_to_widget_json(value: Value) -> Result<String, String> {
    match value {
        Value::String(s) => Ok(s.to_string_lossy().to_owned()),
        _ => Err("render() must return a widget (JSON string from ui.*)".to_string()),
    }
}
