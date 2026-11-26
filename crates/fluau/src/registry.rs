//! Plugin registry: manifests, scripts, and vendored modules.

use lazy_static::lazy_static;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value as JsonValue};
use std::collections::HashMap;
use std::sync::Mutex;

lazy_static! {
    static ref REGISTRY: Mutex<HashMap<String, RegisteredPlugin>> = Mutex::new(HashMap::new());
}

/// One requested host API from the plugin manifest (normalized).
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct HostApiPermission {
    pub id: String,
    /// When true, the plugin cannot start without this grant.
    #[serde(default = "default_true")]
    pub required: bool,
    /// Constraint object as JSON text (e.g. `{"domains":["a.com"]}` or `{}`).
    #[serde(default = "empty_object_json")]
    pub constraints_json: String,
}

fn default_true() -> bool {
    true
}

fn empty_object_json() -> String {
    "{}".into()
}

impl HostApiPermission {
    pub fn constraints_value(&self) -> JsonValue {
        serde_json::from_str(&self.constraints_json).unwrap_or_else(|_| json!({}))
    }
}

/// Declared permissions a plugin requests.
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct PluginPermissions {
    #[serde(default)]
    pub host: Vec<HostApiPermission>,
    #[serde(default)]
    pub libraries: Vec<String>,
}

/// Effective grants for a session (subset of requested host APIs).
#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct PluginGrants {
    #[serde(default)]
    pub host_apis: Vec<String>,
    #[serde(default)]
    pub libraries: Vec<String>,
}

impl PluginGrants {
    /// Grant every requested host API and the declared libraries.
    pub fn all_requested(perms: &PluginPermissions) -> Self {
        Self {
            host_apis: perms.host.iter().map(|h| h.id.clone()).collect(),
            libraries: perms.libraries.clone(),
        }
    }
}

/// Metadata describing a packaged plugin.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PluginManifest {
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
    /// Module name → source (e.g. "helpers" → lib contents).
    modules: HashMap<String, String>,
}

/// One vendored Lua module shipped with a plugin package.
#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct PluginModule {
    pub name: String,
    pub source: String,
}

/// Normalize a host permissions list (YAML/JSON list form or legacy) into [`HostApiPermission`]s.
///
/// List entries:
/// - `"db"` → required, empty constraints
/// - `{ "http": { "domains": [...], "optional": true } }` → strip `optional`, rest = constraints
///
/// Legacy: `host` as string array + top-level `httpAllowlist` / `http_allowlist`.
pub fn normalize_host_permissions(
    host_value: &JsonValue,
    http_allowlist: &[String],
) -> Result<(Vec<HostApiPermission>, Vec<String>), String> {
    let mut warnings = Vec::new();
    let mut out: Vec<HostApiPermission> = Vec::new();
    let mut seen = std::collections::HashSet::new();

    // Legacy: array of strings like ["http.request","db"]
    if let Some(arr) = host_value.as_array() {
        let all_strings = arr.iter().all(|v| v.is_string());
        if all_strings {
            for v in arr {
                let raw = v.as_str().unwrap_or("");
                let id = normalize_legacy_api_id(raw);
                if !seen.insert(id.clone()) {
                    warnings.push(format!(
                        "duplicate host API '{id}' in permissions; keeping first"
                    ));
                    continue;
                }
                let constraints_json = if id == "http" {
                    json!({ "domains": http_allowlist }).to_string()
                } else {
                    "{}".into()
                };
                out.push(HostApiPermission {
                    id,
                    required: true,
                    constraints_json,
                });
            }
            return Ok((out, warnings));
        }

        // New list form: string | single-key map
        for (idx, entry) in arr.iter().enumerate() {
            let (id, mut body) = match entry {
                JsonValue::String(s) => (s.clone(), json!({})),
                JsonValue::Object(map) => {
                    if map.len() != 1 {
                        return Err(format!(
                            "permissions.host[{idx}]: expected a string or a single-key map"
                        ));
                    }
                    let (k, v) = map.iter().next().unwrap();
                    let body = if v.is_null() {
                        json!({})
                    } else if v.is_object() {
                        v.clone()
                    } else if v.is_boolean() && v.as_bool() == Some(true) {
                        json!({})
                    } else {
                        return Err(format!(
                            "permissions.host[{idx}]: value for '{k}' must be a mapping or true"
                        ));
                    };
                    (k.clone(), body)
                }
                _ => {
                    return Err(format!(
                        "permissions.host[{idx}]: expected a string or a single-key map"
                    ));
                }
            };

            let id = normalize_legacy_api_id(&id);
            if !seen.insert(id.clone()) {
                warnings.push(format!(
                    "duplicate host API '{id}' in permissions; keeping first"
                ));
                continue;
            }

            let mut required = true;
            if let Some(obj) = body.as_object_mut() {
                if let Some(opt) = obj.remove("optional") {
                    if let Some(b) = opt.as_bool() {
                        required = !b;
                    } else {
                        return Err(format!(
                            "permissions.host '{id}': optional must be a boolean"
                        ));
                    }
                }
                if let Some(req) = obj.remove("required") {
                    if let Some(b) = req.as_bool() {
                        required = b;
                    }
                }
            }

            out.push(HostApiPermission {
                id,
                required,
                constraints_json: body.to_string(),
            });
        }
        return Ok((out, warnings));
    }

    // Map form (alternate): { "http": {...}, "db": true }
    if let Some(map) = host_value.as_object() {
        for (raw_id, v) in map {
            let id = normalize_legacy_api_id(raw_id);
            if !seen.insert(id.clone()) {
                warnings.push(format!(
                    "duplicate host API '{id}' in permissions; keeping first"
                ));
                continue;
            }
            let mut body = if v.is_boolean() && v.as_bool() == Some(true) {
                json!({})
            } else if v.is_object() {
                v.clone()
            } else if v.is_null() {
                json!({})
            } else {
                return Err(format!(
                    "permissions.host.{raw_id}: expected object or true"
                ));
            };
            let mut required = true;
            if let Some(obj) = body.as_object_mut() {
                if let Some(opt) = obj.remove("optional") {
                    if let Some(b) = opt.as_bool() {
                        required = !b;
                    }
                }
            }
            let constraints_json = if id == "http"
                && body.get("domains").is_none()
                && !http_allowlist.is_empty()
            {
                json!({ "domains": http_allowlist }).to_string()
            } else {
                body.to_string()
            };
            out.push(HostApiPermission {
                id,
                required,
                constraints_json,
            });
        }
        return Ok((out, warnings));
    }

    if host_value.is_null() {
        return Ok((out, warnings));
    }

    Err("permissions.host must be a list or map".into())
}

fn normalize_legacy_api_id(raw: &str) -> String {
    match raw {
        "http.request" => "http".into(),
        "logging" => "log".into(),
        other if other.starts_with("crypto.") => "crypto".into(),
        other => other.to_string(),
    }
}

/// Validate that every host API id is a known builtin (or warn-free accept).
pub fn validate_host_api_ids(perms: &PluginPermissions) -> Result<(), String> {
    let known = crate::host::api_registry::known_api_ids();
    for h in &perms.host {
        if !known.iter().any(|k| *k == h.id) {
            return Err(format!("unknown host API in permissions: '{}'", h.id));
        }
    }
    Ok(())
}

/// Ensure grants cover every required requested API; return session grant map.
pub fn resolve_session_grants(
    requested: &PluginPermissions,
    grants: &PluginGrants,
) -> Result<crate::host::permissions::SessionGrants, String> {
    validate_host_api_ids(requested)?;

    let granted_set: std::collections::HashSet<&str> =
        grants.host_apis.iter().map(|s| s.as_str()).collect();

    for req in &requested.host {
        if req.required && !granted_set.contains(req.id.as_str()) {
            return Err(format!(
                "missing required permission grant for host API '{}'",
                req.id
            ));
        }
    }

    let mut host = HashMap::new();
    for req in &requested.host {
        if granted_set.contains(req.id.as_str()) {
            // Only grant APIs that were actually requested.
            host.insert(req.id.clone(), req.constraints_value());
        }
    }
    // Reject grants for APIs not in the request.
    for g in &grants.host_apis {
        if !requested.host.iter().any(|r| r.id == *g) {
            return Err(format!(
                "cannot grant host API '{g}' which was not requested by the plugin"
            ));
        }
    }

    Ok(crate::host::permissions::SessionGrants {
        host,
        libraries: if grants.libraries.is_empty() {
            requested.libraries.clone()
        } else {
            grants.libraries.clone()
        },
    })
}

/// Register (or replace) a plugin with its Lua source and optional modules.
pub fn register_plugin(
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
    // Empty host permissions are allowed (plugin with no privileged APIs).
    // Unknown API ids are rejected once the app has registered HostApis.
    if !manifest.permissions.host.is_empty() {
        validate_host_api_ids(&manifest.permissions)?;
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

pub fn list_plugins() -> Result<Vec<PluginManifest>, String> {
    let reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    let mut list: Vec<_> = reg.values().map(|p| p.manifest.clone()).collect();
    list.sort_by(|a, b| a.id.cmp(&b.id));
    Ok(list)
}

pub fn get_plugin(plugin_id: &str) -> Result<PluginManifest, String> {
    let reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    reg.get(plugin_id)
        .map(|p| p.manifest.clone())
        .ok_or_else(|| format!("plugin not registered: {plugin_id}"))
}

pub fn plugin_has_capability(plugin_id: &str, capability: &str) -> Result<bool, String> {
    let manifest = get_plugin(plugin_id)?;
    Ok(manifest.capabilities.iter().any(|c| c == capability))
}

pub fn get_script(plugin_id: &str) -> Result<String, String> {
    let reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    reg.get(plugin_id)
        .map(|p| p.script_source.clone())
        .ok_or_else(|| format!("plugin not registered: {plugin_id}"))
}

pub fn get_modules(plugin_id: &str) -> Result<HashMap<String, String>, String> {
    let reg = REGISTRY.lock().map_err(|e| e.to_string())?;
    reg.get(plugin_id)
        .map(|p| p.modules.clone())
        .ok_or_else(|| format!("plugin not registered: {plugin_id}"))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::host::api_registry::{self, HostApiEntry};
    use crate::host::Host;
    use mlua::{Lua, Result as LuaResult, Table};

    fn noop_install(_root: &Table, _host: Host, _lua: &Lua) -> LuaResult<()> {
        Ok(())
    }

    fn register_test_apis(ids: &[&str]) {
        api_registry::clear_host_apis();
        let entries = ids
            .iter()
            .map(|id| HostApiEntry {
                id: (*id).into(),
                path: (*id).into(),
                summary: (*id).into(),
                install: noop_install,
            })
            .collect();
        api_registry::set_host_apis(entries).unwrap();
    }

    #[test]
    fn normalize_legacy_string_list() {
        let host = json!(["http.request", "db", "log"]);
        let (perms, warns) =
            normalize_host_permissions(&host, &["api.example.com".into()]).unwrap();
        assert!(warns.is_empty());
        assert_eq!(perms.len(), 3);
        let http = perms.iter().find(|p| p.id == "http").unwrap();
        assert!(http.required);
        assert!(http.constraints_json.contains("api.example.com"));
        assert!(perms.iter().any(|p| p.id == "db"));
    }

    #[test]
    fn normalize_list_with_optional() {
        let host = json!([
            { "http": { "domains": ["a.com"] } },
            "db",
            { "log": { "optional": true } }
        ]);
        let (perms, _) = normalize_host_permissions(&host, &[]).unwrap();
        let log = perms.iter().find(|p| p.id == "log").unwrap();
        assert!(!log.required);
        let http = perms.iter().find(|p| p.id == "http").unwrap();
        assert!(http.required);
        assert!(http.constraints_json.contains("a.com"));
    }

    #[test]
    fn normalize_duplicate_warns() {
        let host = json!(["db", "db"]);
        let (perms, warns) = normalize_host_permissions(&host, &[]).unwrap();
        assert_eq!(perms.len(), 1);
        assert_eq!(warns.len(), 1);
    }

    #[test]
    fn resolve_grants_requires_required() {
        register_test_apis(&["db", "log"]);
        let requested = PluginPermissions {
            host: vec![
                HostApiPermission {
                    id: "db".into(),
                    required: true,
                    constraints_json: "{}".into(),
                },
                HostApiPermission {
                    id: "log".into(),
                    required: false,
                    constraints_json: "{}".into(),
                },
            ],
            libraries: vec![],
        };
        let err = resolve_session_grants(
            &requested,
            &PluginGrants {
                host_apis: vec!["log".into()],
                libraries: vec![],
            },
        );
        assert!(err.is_err());

        let ok = resolve_session_grants(
            &requested,
            &PluginGrants {
                host_apis: vec!["db".into()],
                libraries: vec![],
            },
        )
        .unwrap();
        assert!(ok.host.contains_key("db"));
        assert!(!ok.host.contains_key("log"));
    }

    #[test]
    fn register_and_list() {
        register_test_apis(&["db"]);
        register_plugin(
            PluginManifest {
                id: "test-reg".into(),
                name: "Test".into(),
                version: "1.0.0".into(),
                script: "x.lua".into(),
                main: "x.lua".into(),
                capabilities: vec!["vpn.provider".into()],
                permissions: PluginPermissions {
                    host: vec![HostApiPermission {
                        id: "db".into(),
                        required: true,
                        constraints_json: "{}".into(),
                    }],
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
