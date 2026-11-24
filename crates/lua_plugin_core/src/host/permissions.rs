//! Central permission gate: grant checks + pluggable constraint checks.

use lazy_static::lazy_static;
use serde_json::Value as JsonValue;
use std::collections::HashMap;
use std::sync::Mutex;

lazy_static! {
    static ref SESSION_GRANTS: Mutex<HashMap<String, SessionGrants>> = Mutex::new(HashMap::new());
    static ref CONSTRAINT_CHECKERS: Mutex<HashMap<String, ConstraintChecker>> =
        Mutex::new(HashMap::new());
}

/// Effective grants bound to a plugin session.
#[derive(Clone, Debug, Default)]
pub struct SessionGrants {
    /// API id → constraint JSON object (may be empty `{}`).
    pub host: HashMap<String, JsonValue>,
    pub libraries: Vec<String>,
}

/// Call-site context for constraint checkers (opaque JSON).
#[derive(Clone, Debug)]
pub enum PermissionUse {
    None,
    /// Opaque context interpreted by the HostApi's registered checker.
    Context(JsonValue),
}

pub type ConstraintChecker =
    fn(constraints: &JsonValue, ctx: &JsonValue) -> Result<(), String>;

/// Shared gate for all permission checks.
pub struct PermissionGate;

impl PermissionGate {
    pub fn bind(plugin_id: &str, grants: SessionGrants) -> Result<(), String> {
        let mut map = SESSION_GRANTS.lock().map_err(|e| e.to_string())?;
        map.insert(plugin_id.to_string(), grants);
        Ok(())
    }

    pub fn clear(plugin_id: &str) {
        if let Ok(mut map) = SESSION_GRANTS.lock() {
            map.remove(plugin_id);
        }
    }

    /// Register a constraint checker for an API id (e.g. HTTP domains).
    pub fn set_constraint_checker(api: &str, checker: ConstraintChecker) -> Result<(), String> {
        let mut map = CONSTRAINT_CHECKERS.lock().map_err(|e| e.to_string())?;
        map.insert(api.to_string(), checker);
        Ok(())
    }

    pub fn clear_constraint_checkers() {
        if let Ok(mut map) = CONSTRAINT_CHECKERS.lock() {
            map.clear();
        }
    }

    pub fn require(plugin_id: &str, api: &str) -> Result<(), String> {
        Self::require_with(plugin_id, api, &PermissionUse::None)
    }

    pub fn require_with(plugin_id: &str, api: &str, ctx: &PermissionUse) -> Result<(), String> {
        let map = SESSION_GRANTS.lock().map_err(|e| e.to_string())?;
        let Some(session) = map.get(plugin_id) else {
            return Err(format!(
                "permission denied: no grants bound for plugin '{plugin_id}' (api '{api}')"
            ));
        };
        let Some(constraints) = session.host.get(api) else {
            return Err(format!(
                "permission denied: plugin '{plugin_id}' is not granted host API '{api}'"
            ));
        };
        match ctx {
            PermissionUse::None => Ok(()),
            PermissionUse::Context(data) => {
                let checkers = CONSTRAINT_CHECKERS.lock().map_err(|e| e.to_string())?;
                if let Some(checker) = checkers.get(api) {
                    checker(constraints, data)
                } else {
                    Ok(())
                }
            }
        }
    }

    pub fn is_granted(plugin_id: &str, api: &str) -> bool {
        let Ok(map) = SESSION_GRANTS.lock() else {
            return false;
        };
        map.get(plugin_id)
            .map(|s| s.host.contains_key(api))
            .unwrap_or(false)
    }

    #[allow(dead_code)]
    pub fn require_library(_plugin_id: &str, _name: &str) -> Result<(), String> {
        Ok(())
    }

    pub fn granted_apis(plugin_id: &str) -> Vec<String> {
        let Ok(map) = SESSION_GRANTS.lock() else {
            return vec![];
        };
        map.get(plugin_id)
            .map(|s| s.host.keys().cloned().collect())
            .unwrap_or_default()
    }

    pub fn constraints(plugin_id: &str, api: &str) -> Option<JsonValue> {
        let Ok(map) = SESSION_GRANTS.lock() else {
            return None;
        };
        map.get(plugin_id)
            .and_then(|s| s.host.get(api).cloned())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn deny_evil(_c: &JsonValue, ctx: &JsonValue) -> Result<(), String> {
        if ctx.get("url").and_then(|u| u.as_str()) == Some("https://evil.com") {
            Err("blocked".into())
        } else {
            Ok(())
        }
    }

    #[test]
    fn require_and_custom_checker() {
        PermissionGate::clear_constraint_checkers();
        PermissionGate::set_constraint_checker("http", deny_evil).unwrap();
        let mut host = HashMap::new();
        host.insert("http".into(), json!({ "domains": ["ok.com"] }));
        PermissionGate::bind(
            "t",
            SessionGrants {
                host,
                libraries: vec![],
            },
        )
        .unwrap();
        assert!(PermissionGate::require("t", "http").is_ok());
        assert!(PermissionGate::require_with(
            "t",
            "http",
            &PermissionUse::Context(json!({ "url": "https://ok.com" }))
        )
        .is_ok());
        assert!(PermissionGate::require_with(
            "t",
            "http",
            &PermissionUse::Context(json!({ "url": "https://evil.com" }))
        )
        .is_err());
        PermissionGate::clear("t");
        PermissionGate::clear_constraint_checkers();
    }
}
