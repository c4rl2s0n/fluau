//! FRB API for plugin registry, sessions, host-backed events, and capabilities.
//!
//! Thin façade over `fluau` — stamped by bootstrap in packaged apps.

use fluau::{
    self as core,
    HostApiPermission as RegistryHostApiPermission, PluginGrants as RegistryGrants,
    PluginManifest as RegistryManifest, PluginModule as RegistryModule,
    PluginPermissions as RegistryPermissions, PluginResponse as SessionPluginResponse,
};
/// One requested host API (normalized).
#[derive(Clone, Debug)]
pub struct HostApiPermission {
    pub id: String,
    pub required: bool,
    /// Constraint object as JSON text (`{}` or `{"domains":[...]}`).
    pub constraints_json: String,
}

impl From<RegistryHostApiPermission> for HostApiPermission {
    fn from(value: RegistryHostApiPermission) -> Self {
        Self {
            id: value.id,
            required: value.required,
            constraints_json: value.constraints_json,
        }
    }
}

impl From<HostApiPermission> for RegistryHostApiPermission {
    fn from(value: HostApiPermission) -> Self {
        Self {
            id: value.id,
            required: value.required,
            constraints_json: value.constraints_json,
        }
    }
}

/// Declared permissions a plugin requests.
#[derive(Clone, Debug, Default)]
pub struct PluginPermissions {
    pub host: Vec<HostApiPermission>,
    pub libraries: Vec<String>,
}

impl From<RegistryPermissions> for PluginPermissions {
    fn from(value: RegistryPermissions) -> Self {
        Self {
            host: value.host.into_iter().map(Into::into).collect(),
            libraries: value.libraries,
        }
    }
}

impl From<PluginPermissions> for RegistryPermissions {
    fn from(value: PluginPermissions) -> Self {
        Self {
            host: value.host.into_iter().map(Into::into).collect(),
            libraries: value.libraries,
        }
    }
}

/// Effective grants for starting a session.
#[derive(Clone, Debug, Default)]
pub struct PluginGrants {
    pub host_apis: Vec<String>,
    pub libraries: Vec<String>,
}

impl From<RegistryGrants> for PluginGrants {
    fn from(value: RegistryGrants) -> Self {
        Self {
            host_apis: value.host_apis,
            libraries: value.libraries,
        }
    }
}

impl From<PluginGrants> for RegistryGrants {
    fn from(value: PluginGrants) -> Self {
        Self {
            host_apis: value.host_apis,
            libraries: value.libraries,
        }
    }
}

/// One vendored Lua module in a plugin package.
#[derive(Clone, Debug)]
pub struct PluginModule {
    pub name: String,
    pub source: String,
}

impl From<PluginModule> for RegistryModule {
    fn from(value: PluginModule) -> Self {
        Self {
            name: value.name,
            source: value.source,
        }
    }
}

/// Metadata describing a packaged plugin.
#[derive(Clone, Debug)]
pub struct PluginManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub script: String,
    pub main: String,
    pub capabilities: Vec<String>,
    pub permissions: PluginPermissions,
}

impl From<RegistryManifest> for PluginManifest {
    fn from(value: RegistryManifest) -> Self {
        Self {
            id: value.id,
            name: value.name,
            version: value.version,
            script: value.script,
            main: value.main,
            capabilities: value.capabilities,
            permissions: value.permissions.into(),
        }
    }
}

impl From<PluginManifest> for RegistryManifest {
    fn from(value: PluginManifest) -> Self {
        Self {
            id: value.id,
            name: value.name,
            version: value.version,
            script: value.script,
            main: value.main,
            capabilities: value.capabilities,
            permissions: value.permissions.into(),
        }
    }
}

/// Response from a plugin event after Rust host intent draining.
#[derive(Clone, Debug)]
pub struct PluginResponse {
    pub widget_json: String,
    pub provide_results: Vec<String>,
}

impl From<SessionPluginResponse> for PluginResponse {
    fn from(value: SessionPluginResponse) -> Self {
        Self {
            widget_json: value.widget_json,
            provide_results: value.provide_results,
        }
    }
}

fn ensure() {
    crate::demo_host::ensure_runtime();
}

/// Register (or replace) a plugin manifest + Lua source + optional modules.
#[flutter_rust_bridge::frb(sync)]
pub fn register_plugin(
    manifest: PluginManifest,
    script_source: String,
    modules: Vec<PluginModule>,
) -> Result<(), String> {
    ensure();
    core::register_plugin(
        manifest.into(),
        script_source,
        modules.into_iter().map(Into::into).collect(),
    )
}

#[flutter_rust_bridge::frb(sync)]
pub fn list_plugins() -> Result<Vec<PluginManifest>, String> {
    ensure();
    Ok(core::registry::list_plugins()?
        .into_iter()
        .map(Into::into)
        .collect())
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_plugin(plugin_id: String) -> Result<PluginManifest, String> {
    ensure();
    core::registry::get_plugin(&plugin_id).map(Into::into)
}

#[flutter_rust_bridge::frb(sync)]
pub fn plugin_has_capability(plugin_id: String, capability: String) -> Result<bool, String> {
    ensure();
    core::registry::plugin_has_capability(&plugin_id, &capability)
}

/// Start with grants covering every requested permission (tests / trusted demos).
#[flutter_rust_bridge::frb(sync)]
pub fn start_registered_plugin(plugin_id: String) -> Result<(), String> {
    ensure();
    core::start_registered_plugin(&plugin_id)
}

/// Start with an explicit grant snapshot (from Dart [`PluginGrantStore`]).
#[flutter_rust_bridge::frb(sync)]
pub fn start_registered_plugin_with_grants(
    plugin_id: String,
    grants: PluginGrants,
) -> Result<(), String> {
    ensure();
    core::start_registered_plugin_with_grants(&plugin_id, grants.into())
}

/// Ad-hoc script session with empty grants (legacy helper).
#[flutter_rust_bridge::frb(sync)]
pub fn start_plugin(plugin_id: String, script: String) -> Result<(), String> {
    ensure();
    let perms = core::PluginPermissions::default();
    let grants = core::PluginGrants::default();
    core::start_plugin(&plugin_id, &script, perms, grants)
}

#[flutter_rust_bridge::frb(sync)]
pub fn stop_plugin(plugin_id: String) -> Result<(), String> {
    ensure();
    core::stop_plugin(&plugin_id)
}

#[flutter_rust_bridge::frb(sync)]
pub fn render_plugin(plugin_id: String) -> Result<String, String> {
    ensure();
    core::render_plugin(&plugin_id)
}

/// Async so crypto + HTTP work does not block the Flutter UI isolate.
pub fn plugin_on_event(
    plugin_id: String,
    event_json: String,
    fields_json: Option<String>,
) -> Result<PluginResponse, String> {
    ensure();
    core::plugin_on_event(&plugin_id, &event_json, fields_json.as_deref()).map(Into::into)
}

/// Async so capability calls that hit the network stay off the UI thread.
pub fn call_plugin(
    plugin_id: String,
    method: String,
    args_json: String,
) -> Result<String, String> {
    ensure();
    core::call_plugin(&plugin_id, &method, &args_json)
}

/// Summaries of registered host APIs for grant UI.
#[derive(Clone, Debug)]
pub struct HostApiInfo {
    pub id: String,
    pub path: String,
    pub summary: String,
}

#[flutter_rust_bridge::frb(sync)]
pub fn list_host_api_info() -> Vec<HostApiInfo> {
    ensure();
    core::host::list_host_apis()
        .into_iter()
        .map(|e| HostApiInfo {
            id: e.id,
            path: e.path,
            summary: e.summary,
        })
        .collect()
}
