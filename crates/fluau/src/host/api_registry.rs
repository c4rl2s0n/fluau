//! Dynamic host API registry: apps register modules at setup; core ships none.

use lazy_static::lazy_static;
use mlua::{Lua, Result as LuaResult, Table};
use std::sync::Mutex;

use super::facade::Host;

/// Description of a host module available to plugins.
#[derive(Clone)]
pub struct HostApiEntry {
    pub id: String,
    pub path: String,
    pub summary: String,
    pub install: fn(&Table, Host, &Lua) -> LuaResult<()>,
}

lazy_static! {
    static ref REGISTRY: Mutex<Vec<HostApiEntry>> = Mutex::new(Vec::new());
}

/// Replace all registered host APIs (call from app `setup`).
pub fn set_host_apis(entries: Vec<HostApiEntry>) -> Result<(), String> {
    let mut reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    *reg = entries;
    Ok(())
}

pub fn register_host_api(entry: HostApiEntry) -> Result<(), String> {
    let mut reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    if reg.iter().any(|e| e.id == entry.id) {
        reg.retain(|e| e.id != entry.id);
    }
    reg.push(entry);
    Ok(())
}

pub fn clear_host_apis() {
    if let Ok(mut reg) = REGISTRY.lock() {
        reg.clear();
    }
}

pub fn list_host_apis() -> Vec<HostApiEntry> {
    REGISTRY
        .lock()
        .map(|r| r.clone())
        .unwrap_or_default()
}

pub fn known_api_ids() -> Vec<String> {
    list_host_apis().into_iter().map(|e| e.id).collect()
}

/// Install every granted registered module onto `host` root.
pub fn inject_granted(lua: &Lua, host: Host, granted_apis: &[String]) -> LuaResult<()> {
    let root = lua.create_table()?;
    let entries = list_host_apis();
    for entry in &entries {
        if granted_apis.iter().any(|g| g == &entry.id) {
            (entry.install)(&root, host.clone(), lua)?;
        }
    }
    lua.globals().set("host", root)?;
    Ok(())
}
