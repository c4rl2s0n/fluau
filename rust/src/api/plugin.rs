//! FRB API for plugin registry, sessions, host-backed events, and capabilities.

use crate::registry::{
    self, PluginManifest as RegistryManifest, PluginModule as RegistryModule,
    PluginPermissions as RegistryPermissions,
};
use crate::session::{self, PluginResponse as SessionPluginResponse};

/// Declared permissions a plugin requests.
#[derive(Clone, Debug, Default)]
pub struct PluginPermissions {
    pub host: Vec<String>,
    pub http_allowlist: Vec<String>,
    pub libraries: Vec<String>,
}

impl From<RegistryPermissions> for PluginPermissions {
    fn from(value: RegistryPermissions) -> Self {
        Self {
            host: value.host,
            http_allowlist: value.http_allowlist,
            libraries: value.libraries,
        }
    }
}

impl From<PluginPermissions> for RegistryPermissions {
    fn from(value: PluginPermissions) -> Self {
        Self {
            host: value.host,
            http_allowlist: value.http_allowlist,
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

/// Register (or replace) a plugin manifest + Lua source + optional modules.
#[flutter_rust_bridge::frb(sync)]
pub fn register_plugin(
    manifest: PluginManifest,
    script_source: String,
    modules: Vec<PluginModule>,
) -> Result<(), String> {
    registry::register_plugin(
        manifest.into(),
        script_source,
        modules.into_iter().map(Into::into).collect(),
    )
}

#[flutter_rust_bridge::frb(sync)]
pub fn list_plugins() -> Result<Vec<PluginManifest>, String> {
    Ok(registry::list_plugins()?
        .into_iter()
        .map(Into::into)
        .collect())
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_plugin(plugin_id: String) -> Result<PluginManifest, String> {
    registry::get_plugin(&plugin_id).map(Into::into)
}

#[flutter_rust_bridge::frb(sync)]
pub fn plugin_has_capability(plugin_id: String, capability: String) -> Result<bool, String> {
    registry::plugin_has_capability(&plugin_id, &capability)
}

#[flutter_rust_bridge::frb(sync)]
pub fn start_registered_plugin(plugin_id: String) -> Result<(), String> {
    session::start_registered_plugin(&plugin_id)
}

#[flutter_rust_bridge::frb(sync)]
pub fn start_plugin(plugin_id: String, script: String) -> Result<(), String> {
    session::start_plugin(&plugin_id, &script)
}

#[flutter_rust_bridge::frb(sync)]
pub fn stop_plugin(plugin_id: String) -> Result<(), String> {
    session::stop_plugin(&plugin_id)
}

#[flutter_rust_bridge::frb(sync)]
pub fn render_plugin(plugin_id: String) -> Result<String, String> {
    session::render_plugin(&plugin_id)
}

/// Async so SRP + HTTP (logicals) do not block the Flutter UI isolate.
pub fn plugin_on_event(
    plugin_id: String,
    event_json: String,
    fields_json: Option<String>,
) -> Result<PluginResponse, String> {
    session::plugin_on_event(&plugin_id, &event_json, fields_json.as_deref()).map(Into::into)
}

/// Async so VPN provider calls that hit the network stay off the UI thread.
pub fn call_plugin(
    plugin_id: String,
    method: String,
    args_json: String,
) -> Result<String, String> {
    session::call_plugin(&plugin_id, &method, &args_json)
}
