/// Callback registry for Lua plugin
///
/// Allows Lua scripts to register callbacks that can be executed from Dart.

use mlua::{Lua, Result, RegistryKey, Thread, Function, Value};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use uuid::Uuid;

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
    pub fn execute(&self, lua: &Lua, id: &str) -> Result<Value> {
        let callbacks = self.callbacks.lock().unwrap();
        let registry_key = callbacks.get(id)
            .ok_or_else(|| mlua::Error::runtime(format!("Callback {} not found", id)))?;
        
        let func: Function = lua.registry_value(registry_key)?;
        func.call::<_, Value>(())
    }
    
    /// Execute a callback by ID with arguments
    pub fn execute_with_args(&self, lua: &Lua, id: &str, args: Vec<Value>) -> Result<Value> {
        let callbacks = self.callbacks.lock().unwrap();
        let registry_key = callbacks.get(id)
            .ok_or_else(|| mlua::Error::runtime(format!("Callback {} not found", id)))?;
        
        let func: Function = lua.registry_value(registry_key)?;
        func.call::<_, Value>(args)
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
lazy_static::lazy_static! {
    pub static ref CALLBACKS: CallbackRegistry = CallbackRegistry::new();
}

/// Register a callback function and return its ID
pub fn register_callback(lua: &Lua, func: Function) -> Result<String> {
    CALLBACKS.register(lua, func)
}

/// Execute a callback by ID with no arguments
/// Returns the result as a string
pub fn execute_callback(id: String) -> Result<String, String> {
    let lua = Lua::new();
    let result = CALLBACKS.execute(&lua, &id)
        .map(|v| v.to_string())
        .map_err(|e| e.to_string())?;
    Ok(result)
}

/// Execute a callback by ID with arguments
/// Arguments are passed as a JSON array string
pub fn execute_callback_with_args(id: String, args_json: String) -> Result<String, String> {
    let lua = Lua::new();
    
    // Parse arguments from JSON
    let args: Vec<Value> = serde_json::from_str(&args_json)
        .map_err(|e| format!("Invalid JSON arguments: {}", e))?;
    
    let result = CALLBACKS.execute_with_args(&lua, &id, args)
        .map(|v| v.to_string())
        .map_err(|e| e.to_string())?;
    Ok(result)
}

/// Remove a callback by ID
pub fn remove_callback(id: String) -> Result<bool, String> {
    Ok(CALLBACKS.remove(&id))
}

/// Clear all callbacks
pub fn clear_callbacks() -> Result<(), String> {
    CALLBACKS.clear();
    Ok(())
}
