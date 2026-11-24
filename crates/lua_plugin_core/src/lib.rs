//! Tools-only Luau plugin runtime.
//!
//! Concrete HostAPIs and UI widget catalogs are registered by the host app via [`setup`].

pub mod host;
pub mod json_util;
pub mod registry;
pub mod session;
pub mod setup;
pub mod ui;

pub use host::{
    Host, HostApiEntry, IntentHandler, IntentOutcome, PermissionGate, PermissionUse, SessionGrants,
};
pub use registry::{
    HostApiPermission, PluginGrants, PluginManifest, PluginModule, PluginPermissions,
    get_modules, get_plugin, get_script, list_plugins, normalize_host_permissions,
    plugin_has_capability, register_plugin, resolve_session_grants, validate_host_api_ids,
};
pub use session::{
    PluginResponse, SessionCleanupFn, SessionPrepareFn, call_plugin, plugin_on_event,
    render_plugin, set_session_cleanup, set_session_prepare, start_plugin,
    start_plugin_with_modules, start_registered_plugin, start_registered_plugin_with_grants,
    stop_plugin,
};
pub use setup::{SetupOptions, setup};
pub use ui::{UiSetupFn, set_ui_setup};

/// Re-export macros so apps can depend on core alone for `#[host_module]`.
pub use host_api_macros::{host_module, host_userdata, HostType, HostUserData};
