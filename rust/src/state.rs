/// State management for Lua plugin
///
/// Provides thread-safe state storage that can be accessed from Lua scripts.

use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use serde_json::{Value, json};

/// Thread-safe Lua state store
#[derive(Debug, Default)]
pub struct LuaStateStore {
    state: Arc<RwLock<HashMap<String, Value>>>,
}

impl LuaStateStore {
    /// Create a new state store
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(HashMap::new())),
        }
    }
    
    /// Get a state value by key
    pub fn get(&self, key: &str) -> Option<Value> {
        let state = self.state.read().unwrap();
        state.get(key).cloned()
    }
    
    /// Set a state value
    pub fn set(&self, key: String, value: Value) {
        let mut state = self.state.write().unwrap();
        state.insert(key, value);
    }
    
    /// Get all state as a JSON value
    pub fn get_all(&self) -> Value {
        let state = self.state.read().unwrap();
        json!(state.iter().collect::<HashMap<_, _>>())
    }
    
    /// Delete a state value
    pub fn delete(&self, key: &str) -> bool {
        let mut state = self.state.write().unwrap();
        state.remove(key).is_some()
    }
    
    /// Clear all state
    pub fn clear(&self) {
        let mut state = self.state.write().unwrap();
        state.clear();
    }
}

/// Global state store instance
lazy_static::lazy_static! {
    pub static ref STATE: LuaStateStore = LuaStateStore::new();
}

/// Get a state value by key
pub fn get_state(key: &str) -> Result<String, String> {
    STATE.get(key)
        .map(|v| v.to_string())
        .ok_or_else(|| format!("State key '{}' not found", key))
}

/// Set a state value from a JSON string
pub fn set_state(key: String, value: String) -> Result<(), String> {
    let json_value: Value = serde_json::from_str(&value)
        .map_err(|e| format!("Invalid JSON: {}", e))?;
    STATE.set(key, json_value);
    Ok(())
}

/// Get all state as a JSON string
pub fn get_all_state() -> Result<String, String> {
    Ok(STATE.get_all().to_string())
}

/// Delete a state value
pub fn delete_state(key: String) -> Result<bool, String> {
    Ok(STATE.delete(&key))
}

/// Clear all state
pub fn clear_state() -> Result<(), String> {
    STATE.clear();
    Ok(())
}
