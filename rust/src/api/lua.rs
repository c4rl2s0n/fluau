//! Lua API for Flutter widget generation using mlua UserData
//! 
//! This module provides the Lua API that allows Lua scripts to create Flutter widgets.
//! It uses mlua's UserData feature to provide type-safe Lua ↔ Rust interop.
//!
//! The approach uses UserData to expose Rust structs directly to Lua, providing
//! better type safety and a more structured API compared to plain tables.

use mlua::{Lua, Result as LuaResult, Table, UserData, UserDataFields, Value};
use serde::{Deserialize, Serialize};
use serde_json::{Map as JsonMap, Value as JsonValue};

/// Represents the style properties for a Text widget
/// This is a plain struct (not UserData) that we parse from Lua tables
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextStyle {
    #[serde(default)]
    pub font_size: Option<f64>,
    #[serde(default)]
    pub color: Option<String>,
    #[serde(default)]
    pub font_weight: Option<String>,
    #[serde(default)]
    pub font_style: Option<String>,
}

/// Represents a Text widget that can be created from Lua
/// This struct is exposed to Lua as a UserData type
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TextWidget {
    pub text: String,
    #[serde(default)]
    pub style: Option<TextStyle>,
}

impl UserData for TextWidget {
    fn add_fields<F: UserDataFields<Self>>(fields: &mut F) {
        // Text content (required string)
        fields.add_field_method_get("text", |_, this| Ok(this.text.clone()));
        fields.add_field_method_set("text", |_, this, value: String| {
            this.text = value;
            Ok(())
        });
        
        // Style property - we handle this as a Lua table, not UserData
        // This avoids the complexity of nested UserData types
        fields.add_field_method_get("style", |lua, this| {
            // Return style as a Lua table
            let table = lua.create_table()?;
            if let Some(style) = &this.style {
                if let Some(fs) = style.font_size {
                    table.set("fontSize", fs)?;
                }
                if let Some(c) = &style.color {
                    table.set("color", c.clone())?;
                }
                if let Some(fw) = &style.font_weight {
                    table.set("fontWeight", fw.clone())?;
                }
                if let Some(fst) = &style.font_style {
                    table.set("fontStyle", fst.clone())?;
                }
            }
            Ok(Value::Table(table))
        });
        
        fields.add_field_method_set("style", |_, this, value: Value| {
            // Parse style from Lua table
            match value {
                Value::Table(style_table) => {
                    let mut style = TextStyle {
                        font_size: None,
                        color: None,
                        font_weight: None,
                        font_style: None,
                    };
                    
                    if let Ok(fs) = style_table.get::<f64>("fontSize") {
                        style.font_size = Some(fs);
                    }
                    if let Ok(c) = style_table.get::<String>("color") {
                        style.color = Some(c);
                    }
                    if let Ok(fw) = style_table.get::<String>("fontWeight") {
                        style.font_weight = Some(fw);
                    }
                    if let Ok(fst) = style_table.get::<String>("fontStyle") {
                        style.font_style = Some(fst);
                    }
                    
                    this.style = Some(style);
                    Ok(())
                }
                Value::Nil => {
                    this.style = None;
                    Ok(())
                }
                _ => Err(mlua::Error::external("Style must be a table or nil"))
            }
        });
    }
}

/// Convert TextWidget to JSON for sending to Flutter
fn text_widget_to_json(widget: &TextWidget) -> JsonValue {
    let mut map = JsonMap::new();
    map.insert("type".to_string(), JsonValue::String("Text".to_string()));
    map.insert("text".to_string(), JsonValue::String(widget.text.clone()));
    
    if let Some(style) = &widget.style {
        let mut style_map = JsonMap::new();
        if let Some(font_size) = style.font_size {
            style_map.insert("fontSize".to_string(), JsonValue::Number(serde_json::Number::from_f64(font_size).unwrap_or(serde_json::Number::from(0))));
        }
        if let Some(color) = &style.color {
            style_map.insert("color".to_string(), JsonValue::String(color.clone()));
        }
        if let Some(font_weight) = &style.font_weight {
            style_map.insert("fontWeight".to_string(), JsonValue::String(font_weight.clone()));
        }
        if let Some(font_style) = &style.font_style {
            style_map.insert("fontStyle".to_string(), JsonValue::String(font_style.clone()));
        }
        if !style_map.is_empty() {
            map.insert("style".to_string(), JsonValue::Object(style_map));
        }
    }
    
    JsonValue::Object(map)
}

/// Register the widget API with Lua
/// This sets up the `ui` global table with widget constructors
fn register_widget_api(lua: &Lua) -> LuaResult<()> {
    // Create the ui table
    let ui = lua.create_table()?;
    
    // Register Text widget constructor
    // ui.Text{text = "hello", style = {fontSize = 24}} creates a TextWidget UserData
    ui.set("Text", lua.create_function(|lua, args: Table| {
        let text: String = args.get("text")?;
        
        let mut widget = TextWidget {
            text,
            style: None,
        };
        
        // Parse style if present (as a Lua table, not UserData)
        if let Ok(style_table) = args.get::<Table>("style") {
            let mut style = TextStyle {
                font_size: None,
                color: None,
                font_weight: None,
                font_style: None,
            };
            
            if let Ok(font_size) = style_table.get::<f64>("fontSize") {
                style.font_size = Some(font_size);
            }
            if let Ok(color) = style_table.get::<String>("color") {
                style.color = Some(color);
            }
            if let Ok(font_weight) = style_table.get::<String>("fontWeight") {
                style.font_weight = Some(font_weight);
            }
            if let Ok(font_style) = style_table.get::<String>("fontStyle") {
                style.font_style = Some(font_style);
            }
            
            widget.style = Some(style);
        }
        
        // Return the widget as a Lua UserData
        Ok(Value::UserData(lua.create_userdata(widget)?))
    })?)?;
    
    // Register the ui table globally
    lua.globals().set("ui", ui)?;
    
    Ok(())
}

/// Execute a Lua script and return the resulting widget as JSON
/// 
/// This function:
/// 1. Creates a new Lua state with sandboxing enabled
/// 2. Registers the widget API (ui.Text, etc.)
/// 3. Executes the script which should return a widget
/// 4. Converts the widget to JSON for Flutter to parse
#[flutter_rust_bridge::frb(sync)]
pub fn run_lua_ui_script(script: String) -> Result<String, String> {
    let lua = Lua::new();
    
    // Enable sandboxing - Luau feature provides security
    lua.sandbox(true);
    
    // Register our widget API
    if let Err(e) = register_widget_api(&lua) {
        return Err(e.to_string());
    }
    
    // Execute the script - it should return a TextWidget UserData
    match lua.load(&script).eval::<Value>() {
        Ok(Value::UserData(userdata)) => {
            // Extract TextWidget from UserData
            match userdata.borrow::<TextWidget>() {
                Ok(widget) => {
                    let json_value = text_widget_to_json(&widget);
                    serde_json::to_string(&json_value).map_err(|e| e.to_string())
                }
                Err(_) => Err("Lua script did not return a TextWidget UserData".to_string()),
            }
        }
        Ok(_) => Err("Lua script did not return a UserData widget".to_string()),
        Err(e) => Err(e.to_string()),
    }
}

/// Initialize the Lua environment
/// Called when the Flutter app starts
#[flutter_rust_bridge::frb(init)]
pub fn init_lua() {
    // Initialization logic can go here
}
