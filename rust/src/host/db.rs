//! Per-plugin key/value store (in-memory for the PoC; durable path later).

use lazy_static::lazy_static;
use std::collections::HashMap;
use std::sync::Mutex;

lazy_static! {
    static ref DB: Mutex<HashMap<String, HashMap<String, String>>> =
        Mutex::new(HashMap::new());
}

pub fn set(plugin_id: &str, key: &str, value: &str) -> Result<(), String> {
    let mut db = DB.lock().map_err(|e| e.to_string())?;
    db.entry(plugin_id.to_string())
        .or_default()
        .insert(key.to_string(), value.to_string());
    Ok(())
}

pub fn get(plugin_id: &str, key: &str) -> Result<Option<String>, String> {
    let db = DB.lock().map_err(|e| e.to_string())?;
    Ok(db.get(plugin_id).and_then(|m| m.get(key).cloned()))
}
