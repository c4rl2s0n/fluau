// Lua Engine for executing Lua scripts that define UI widgets
//
// This module provides the Lua execution environment and widget construction.

use mlua::{Lua, Result, Table};
use serde_json::{json, Value as JsonValue};

/// Execute a Lua script that returns a widget definition
/// The Lua script should return a table with widget properties
/// This function converts that table to JSON for Dart to process
pub fn execute_ui_script(script: &str) -> std::result::Result<String, String> {
    let lua = Lua::new();
    
    // Set up the ui table with widget constructors
    let ui = lua.create_table().map_err(|e| e.to_string())?;
    
    // ui.Text constructor
    ui.set("Text", lua.create_function(|_, args: Table| {
        let text: String = args.get("text")
            .ok_or_else(|| mlua::Error::runtime("Text: missing required property 'text'"))??;
        
        let mut map = serde_json::Map::new();
        map.insert("type".to_string(), json!("Text"));
        map.insert("text".to_string(), json!(text));
        
        if let Ok(size) = args.get::<Option<String>,"size") {
            // Validate size enum
            if let Some(ref v) = size {
                if !["small", "medium", "large"].contains(&v.as_str()) {
                    return Err(mlua::Error::runtime("Text: invalid size value"));
                }
            }
            map.insert("size".to_string(), json!(size));
        }
        
        if let Ok(color) = args.get::<Option<String>,"color") {
            // Validate color enum
            if let Some(ref v) = color {
                if !["primary", "secondary", "error", "text"].contains(&v.as_str()) {
                    return Err(mlua::Error::runtime("Text: invalid color value"));
                }
            }
            map.insert("color".to_string(), json!(color));
        }
        
        if let Ok(weight) = args.get::<Option<String>,"weight") {
            // Validate weight enum
            if let Some(ref v) = weight {
                if !["normal", "bold"].contains(&v.as_str()) {
                    return Err(mlua::Error::runtime("Text: invalid weight value"));
                }
            }
            map.insert("weight".to_string(), json!(weight));
        }
        
        Ok(JsonValue::Object(map))
    })?).map_err(|e| e.to_string())?;
    
    // ui.Button constructor
    ui.set("Button", lua.create_function(|_, args: Table| {
        let mut map = serde_json::Map::new();
        map.insert("type".to_string(), json!("Button"));
        
        if let Ok(text) = args.get::<Option<String>,"text") {
            map.insert("text".to_string(), json!(text));
        }
        
        if let Ok(on_pressed) = args.get::<Option<String>,"onPressed") {
            map.insert("onPressed".to_string(), json!(on_pressed));
        }
        
        Ok(JsonValue::Object(map))
    })?).map_err(|e| e.to_string())?;
    
    // ui.Column constructor
    ui.set("Column", lua.create_function(|_, args: Table| {
        let mut map = serde_json::Map::new();
        map.insert("type".to_string(), json!("Column"));
        
        if let Ok(spacing) = args.get::<Option<f64>,"spacing") {
            map.insert("spacing".to_string(), json!(spacing));
        }
        
        if let Ok(main_axis_alignment) = args.get::<Option<String>,"mainAxisAlignment") {
            if let Some(ref v) = main_axis_alignment {
                if !["start", "center", "end", "spaceBetween", "spaceAround", "spaceEvenly"].contains(&v.as_str()) {
                    return Err(mlua::Error::runtime("Column: invalid mainAxisAlignment value"));
                }
            }
            map.insert("mainAxisAlignment".to_string(), json!(main_axis_alignment));
        }
        
        if let Ok(cross_axis_alignment) = args.get::<Option<String>,"crossAxisAlignment") {
            if let Some(ref v) = cross_axis_alignment {
                if !["start", "center", "end", "stretch", "baseline"].contains(&v.as_str()) {
                    return Err(mlua::Error::runtime("Column: invalid crossAxisAlignment value"));
                }
            }
            map.insert("crossAxisAlignment".to_string(), json!(cross_axis_alignment));
        }
        
        // Handle children
        if let Ok(children) = args.get::<Option<Table>,"children") {
            if let Some(child_table) = children {
                let mut children_json = Vec::new();
                for pair in child_table.pairs::<mlua::Value, mlua::Value>() {
                    if let Ok((_, child_value)) = pair {
                        // Recursively process child - for now just convert to string
                        // This is a simplification; in production we'd need proper handling
                        children_json.push(json!(child_value.to_string()));
                    }
                }
                map.insert("children".to_string(), json!(children_json));
            }
        }
        
        Ok(JsonValue::Object(map))
    })?).map_err(|e| e.to_string())?;
    
    // State management
    ui.set("getState", lua.create_function(|_, key: String| {
        crate::state::get_state(&key).map_err(|e| mlua::Error::runtime(e))
    })?).map_err(|e| e.to_string())?;
    
    ui.set("setState", lua.create_function(|_, (key, value): (String, String)| {
        crate::state::set_state(key, value).map_err(|e| mlua::Error::runtime(e))
    })?).map_err(|e| e.to_string())?;
    
    ui.set("getAllState", lua.create_function(|_, ()| {
        crate::state::get_all_state().map_err(|e| mlua::Error::runtime(e))
    })?).map_err(|e| e.to_string())?;
    
    // Callback registration
    ui.set("registerCallback", lua.create_function(|lua, func: mlua::Function| {
        crate::callbacks::register_callback(lua, func).map_err(|e| mlua::Error::runtime(e.to_string()))
    })?).map_err(|e| e.to_string())?;
    
    lua.globals().set("ui", ui).map_err(|e| e.to_string())?;
    
    // Execute the script
    let result: JsonValue = lua.load(script)
        .eval()
        .map_err(|e| e.to_string())?;
    
    Ok(result.to_string())
}
