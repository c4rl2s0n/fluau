/// Callback registry for Lua plugin
///
/// Allows Lua scripts to register callbacks that can be executed from Dart.

use mlua::{Lua, Result, RegistryKey, Function};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use uuid::Uuid;

// Re-export for lazy_static
use lazy_static::lazy_static;

/// Stores Lua callbacks with unique IDs
#[derive(Debug, Default)]
pub struct CallbackRegistry {
    callbacks: Arc<Mutex<HashMap<String, RegistryKey>>>,
}

impl CallbackRegistry {
    /// Create a new callback registry
    pub fn new() -> Self {
        Self {
            callbacks: Arc::new(Mutex::new(HashMap::new())),
        }
    }
    
    /// Register a Lua function with a unique ID
    /// Returns the callback ID that can be used to execute the callback later
    pub fn register(&self, lua: &Lua, func: Function) -> Result<String> {
        let registry_key = lua.create_registry_value(func)?;
        let id = Uuid::new_v4().to_string();
        
        let mut callbacks = self.callbacks.lock().unwrap();
        callbacks.insert(id.clone(), registry_key);
        
        Ok(id)
    }
    
    /// Execute a callback by ID with no arguments
    pub fn execute(&self, lua: &Lua, id: &str) -> Result<String> {
        let callbacks = self.callbacks.lock().unwrap();
        let registry_key = callbacks.get(id)
            .ok_or_else(|| mlua::Error::runtime(format!("Callback {} not found", id)))?;
        
        let func: Function = lua.registry_value(registry_key)?;
        // Call with no arguments and return the result as a string
        let result: mlua::Value = func.call(())?;
        Ok(result.to_string()?)
    }
    
    /// Execute a callback by ID with arguments
    pub fn execute_with_args(&self, lua: &Lua, id: &str, args: Vec<String>) -> Result<String> {
        let callbacks = self.callbacks.lock().unwrap();
        let registry_key = callbacks.get(id)
            .ok_or_else(|| mlua::Error::runtime(format!("Callback {} not found", id)))?;
        
        let func: Function = lua.registry_value(registry_key)?;
        // Convert args to mlua::Value and call
        let lua_args: Result<Vec<mlua::Value>> = args.into_iter()
            .map(|s| Ok(mlua::Value::String(lua.create_string(s)?.into())))
            .collect();
        let lua_args = lua_args?;
        let result: mlua::Value = func.call(lua_args)?;
        Ok(result.to_string()?)
    }
    
    /// Remove a callback by ID
    pub fn remove(&self, id: &str) -> bool {
        let mut callbacks = self.callbacks.lock().unwrap();
        callbacks.remove(id).is_some()
    }
    
    /// Clear all callbacks
    pub fn clear(&self) {
        let mut callbacks = self.callbacks.lock().unwrap();
        callbacks.clear();
    }
}

/// Global callback registry instance
lazy_static! {
    pub static ref CALLBACKS: CallbackRegistry = CallbackRegistry::new();
}

/// Register a callback function and return its ID
pub fn register_callback(lua: &Lua, func: Function) -> Result<String> {
    CALLBACKS.register(lua, func)
}

/// Execute a callback by ID with no arguments
/// Returns the result as a string
pub fn execute_callback(id: String) -> std::result::Result<String, String> {
    let lua = Lua::new();
    match CALLBACKS.execute(&lua, &id) {
        Ok(result) => Ok(result),
        Err(e) => Err(e.to_string()),
    }
}

/// Execute a callback by ID with arguments (as JSON array of strings)
/// Returns the result as a string
pub fn execute_callback_with_args(id: String, args_json: String) -> std::result::Result<String, String> {
    let lua = Lua::new();
    
    // Parse arguments from JSON array
    let args: Vec<String> = match serde_json::from_str(&args_json) {
        Ok(v) => v,
        Err(e) => return Err(format!("Invalid JSON arguments: {}", e)),
    };
    
    match CALLBACKS.execute_with_args(&lua, &id, args) {
        Ok(result) => Ok(result),
        Err(e) => Err(e.to_string()),
    }
}

/// Remove a callback by ID
pub fn remove_callback(id: String) -> std::result::Result<bool, String> {
    Ok(CALLBACKS.remove(&id))
}

/// Clear all callbacks
pub fn clear_callbacks() -> std::result::Result<(), String> {
    CALLBACKS.clear();
    Ok(())
}
