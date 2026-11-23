//! Plugin registry: manifests, scripts, and vendored modules.

use lazy_static::lazy_static;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Mutex;

lazy_static! {
    static ref REGISTRY: Mutex<HashMap<String, RegisteredPlugin>> = Mutex::new(HashMap::new());
}

/// Declared permissions a plugin requests (enforced by the host / future UI grant).
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub(crate) struct PluginPermissions {
    #[serde(default)]
    pub host: Vec<String>,
    #[serde(default, alias = "httpAllowlist")]
    pub http_allowlist: Vec<String>,
    #[serde(default)]
    pub libraries: Vec<String>,
}

/// Metadata describing a packaged plugin.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub(crate) struct PluginManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    /// Asset or package-relative main script path (informational).
    #[serde(default)]
    pub script: String,
    /// Preferred entry file name inside the package (defaults to script / main.lua).
    #[serde(default)]
    pub main: String,
    #[serde(default)]
    pub capabilities: Vec<String>,
    #[serde(default)]
    pub permissions: PluginPermissions,
}

#[derive(Clone, Debug)]
struct RegisteredPlugin {
    manifest: PluginManifest,
    script_source: String,
    /// Module name → source (e.g. "proton_srp" → lib contents).
    modules: HashMap<String, String>,
}

/// One vendored Lua module shipped with a plugin package.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub(crate) struct PluginModule {
    pub name: String,
    pub source: String,
}

/// Register (or replace) a plugin with its Lua source and optional modules.
pub(crate) fn register_plugin(
    mut manifest: PluginManifest,
    script_source: String,
    modules: Vec<PluginModule>,
) -> Result<(), String> {
    if manifest.id.is_empty() {
        return Err("plugin id must not be empty".to_string());
    }
    if script_source.trim().is_empty() {
        return Err("plugin script must not be empty".to_string());
    }
    if manifest.script.is_empty() && !manifest.main.is_empty() {
        manifest.script = manifest.main.clone();
    }
    if manifest.main.is_empty() && !manifest.script.is_empty() {
        manifest.main = manifest.script.clone();
    }
    // Default permissions for simple demos if omitted.
    if manifest.permissions.host.is_empty() {
        manifest.permissions.host = vec!["http.request".into(), "db".into()];
    }

    let mut module_map = HashMap::new();
    for m in modules {
        if m.name.is_empty() || m.source.trim().is_empty() {
            continue;
        }
        module_map.insert(m.name, m.source);
    }

    let mut reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    let id = manifest.id.clone();
    reg.insert(
        id,
        RegisteredPlugin {
            manifest,
            script_source,
            modules: module_map,
        },
    );
    Ok(())
}

pub(crate) fn list_plugins() -> Result<Vec<PluginManifest>, String> {
    let reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    let mut list: Vec<_> = reg.values().map(|p| p.manifest.clone()).collect();
    list.sort_by(|a, b| a.id.cmp(&b.id));
    Ok(list)
}

pub(crate) fn get_plugin(plugin_id: &str) -> Result<PluginManifest, String> {
    let reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    reg.get(plugin_id)
        .map(|p| p.manifest.clone())
        .ok_or_else(|| format!("plugin not registered: {plugin_id}"))
}

pub(crate) fn plugin_has_capability(plugin_id: &str, capability: &str) -> Result<bool, String> {
    let manifest = get_plugin(plugin_id)?;
    Ok(manifest.capabilities.iter().any(|c| c == capability))
}

pub(crate) fn get_script(plugin_id: &str) -> Result<String, String> {
    let reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    reg.get(plugin_id)
        .map(|p| p.script_source.clone())
        .ok_or_else(|| format!("plugin not registered: {plugin_id}"))
}

pub(crate) fn get_modules(plugin_id: &str) -> Result<HashMap<String, String>, String> {
    let reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    reg.get(plugin_id)
        .map(|p| p.modules.clone())
        .ok_or_else(|| format!("plugin not registered: {plugin_id}"))
}

pub(crate) fn library_allowed(plugin_id: &str, name: &str) -> Result<bool, String> {
    let manifest = get_plugin(plugin_id)?;
    let libs = &manifest.permissions.libraries;
    if libs.is_empty() {
        // No library declarations → allow any module shipped with the package.
        return Ok(true);
    }
    let plugin_key = format!("plugin:{name}");
    Ok(libs.iter().any(|l| l == name || l == &plugin_key))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn register_and_list() {
        register_plugin(
            PluginManifest {
                id: "test-reg".into(),
                name: "Test".into(),
                version: "1.0.0".into(),
                script: "x.lua".into(),
                main: "x.lua".into(),
                capabilities: vec!["vpn.provider".into()],
                permissions: PluginPermissions {
                    host: vec!["db".into()],
                    http_allowlist: vec![],
                    libraries: vec![],
                },
            },
            "function render() end".into(),
            vec![],
        )
        .unwrap();
        let list = list_plugins().unwrap();
        assert!(list.iter().any(|m| m.id == "test-reg"));
        assert!(plugin_has_capability("test-reg", "vpn.provider").unwrap());
    }
}
