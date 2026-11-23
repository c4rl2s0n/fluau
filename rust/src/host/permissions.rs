//! Central permission gate: grant checks + pluggable constraint checks.
//!
//! All privileged call sites (sync host, UserData, intents, `require`) go through
//! [`PermissionGate`]. Module-specific rules (e.g. HTTP domains) run as constraint
//! checkers invoked by the same gate.

use lazy_static::lazy_static;
use serde_json::Value as JsonValue;
use std::collections::HashMap;
use std::sync::Mutex;

use super::http;

lazy_static! {
    static ref SESSION_GRANTS: Mutex<HashMap<String, SessionGrants>> = Mutex::new(HashMap::new());
}

/// Effective grants bound to a plugin session.
#[derive(Clone, Debug, Default)]
pub struct SessionGrants {
    /// API id → constraint JSON object (may be empty `{}`).
    pub host: HashMap<String, JsonValue>,
    pub libraries: Vec<String>,
}

/// Call-site context for constraint checkers.
#[derive(Clone, Debug)]
pub enum PermissionUse {
    /// No extra context (grant check only).
    None,
    /// HTTP request about to be issued.
    Http { url: String },
}

/// Shared gate for all permission checks.
pub struct PermissionGate;

impl PermissionGate {
    /// Bind effective grants for a plugin session (replaces any previous).
    pub fn bind(plugin_id: &str, grants: SessionGrants) -> Result<(), String> {
        let mut map = SESSION_GRANTS.lock().map_err(|e| e.to_string())?;
        map.insert(plugin_id.to_string(), grants);
        Ok(())
    }

    /// Drop grant state when a session stops.
    pub fn clear(plugin_id: &str) {
        if let Ok(mut map) = SESSION_GRANTS.lock() {
            map.remove(plugin_id);
        }
    }

    /// Require that `api` is granted (no extra constraints).
    pub fn require(plugin_id: &str, api: &str) -> Result<(), String> {
        Self::require_with(plugin_id, api, &PermissionUse::None)
    }

    /// Require grant and run the module's constraint checker with `ctx`.
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
        check_constraints(api, constraints, ctx)
    }

    /// Whether `api` is currently granted (no constraint check).
    pub fn is_granted(plugin_id: &str, api: &str) -> bool {
        let Ok(map) = SESSION_GRANTS.lock() else {
            return false;
        };
        map.get(plugin_id)
            .map(|s| s.host.contains_key(api))
            .unwrap_or(false)
    }

    /// Reserved for a future host-mediated external Luau library feature.
    ///
    /// Package-local `require` does **not** use this: modules ship with the plugin
    /// and resolve from the session module map only.
    #[allow(dead_code)]
    pub fn require_library(_plugin_id: &str, _name: &str) -> Result<(), String> {
        Ok(())
    }

    /// Snapshot of granted API ids (for inject filtering).
    pub fn granted_apis(plugin_id: &str) -> Vec<String> {
        let Ok(map) = SESSION_GRANTS.lock() else {
            return vec![];
        };
        map.get(plugin_id)
            .map(|s| s.host.keys().cloned().collect())
            .unwrap_or_default()
    }

    /// Constraints JSON for a granted API (if any).
    pub fn constraints(plugin_id: &str, api: &str) -> Option<JsonValue> {
        let Ok(map) = SESSION_GRANTS.lock() else {
            return None;
        };
        map.get(plugin_id)
            .and_then(|s| s.host.get(api).cloned())
    }
}

fn check_constraints(api: &str, constraints: &JsonValue, ctx: &PermissionUse) -> Result<(), String> {
    match (api, ctx) {
        ("http", PermissionUse::Http { url }) => {
            let domains = domains_from_constraints(constraints);
            if domains.is_empty() {
                return Err(
                    "permission denied: http granted but domains allowlist is empty".into(),
                );
            }
            if http::host_allowed(url, &domains) {
                Ok(())
            } else {
                Err(format!(
                    "host not allowed by plugin http domains: {}",
                    http::host_of(url).unwrap_or_else(|| url.clone())
                ))
            }
        }
        ("http", PermissionUse::None) => {
            // Grant-only check already passed; no URL yet.
            Ok(())
        }
        _ => Ok(()),
    }
}

fn domains_from_constraints(constraints: &JsonValue) -> Vec<String> {
    constraints
        .get("domains")
        .and_then(|v| v.as_array())
        .map(|arr| {
            arr.iter()
                .filter_map(|x| x.as_str().map(|s| s.to_string()))
                .collect()
        })
        .unwrap_or_default()
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn bind_http(plugin_id: &str, domains: &[&str]) {
        let mut host = HashMap::new();
        host.insert(
            "http".into(),
            json!({ "domains": domains }),
        );
        host.insert("db".into(), json!({}));
        PermissionGate::bind(
            plugin_id,
            SessionGrants {
                host,
                libraries: vec![],
            },
        )
        .unwrap();
    }

    #[test]
    fn require_denies_ungranted_api() {
        bind_http("gate-1", &["example.com"]);
        assert!(PermissionGate::require("gate-1", "db").is_ok());
        assert!(PermissionGate::require("gate-1", "crypto").is_err());
        PermissionGate::clear("gate-1");
    }

    #[test]
    fn http_domain_checker() {
        bind_http("gate-2", &["api.example.com"]);
        assert!(PermissionGate::require_with(
            "gate-2",
            "http",
            &PermissionUse::Http {
                url: "https://api.example.com/v1".into()
            }
        )
        .is_ok());
        assert!(PermissionGate::require_with(
            "gate-2",
            "http",
            &PermissionUse::Http {
                url: "https://evil.com/x".into()
            }
        )
        .is_err());
        PermissionGate::clear("gate-2");
    }
}
