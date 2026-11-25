//! Tools-only Luau plugin runtime for Flutter hosts.
//!
//! Concrete HostAPIs and UI widget catalogs are registered by the app via [`setup`]
//! (requires the `runtime` feature, enabled by default).
//!
//! Enable `stub-gen` (without `runtime`) from `build.rs` to emit Luau host stubs.

#![cfg_attr(not(feature = "runtime"), allow(unused_imports))]

#[cfg(feature = "runtime")]
pub mod host;
#[cfg(feature = "runtime")]
pub mod json_util;
#[cfg(feature = "runtime")]
pub mod registry;
#[cfg(feature = "runtime")]
pub mod session;
#[cfg(feature = "runtime")]
pub mod setup;
#[cfg(feature = "runtime")]
pub mod ui;

#[cfg(feature = "stub-gen")]
pub mod stub_gen;

#[cfg(feature = "runtime")]
pub use host::{
    Host, HostApiEntry, IntentHandler, IntentOutcome, PermissionGate, PermissionUse, SessionGrants,
};
#[cfg(feature = "runtime")]
pub use registry::{
    HostApiPermission, PluginGrants, PluginManifest, PluginModule, PluginPermissions,
    get_modules, get_plugin, get_script, list_plugins, normalize_host_permissions,
    plugin_has_capability, register_plugin, resolve_session_grants, validate_host_api_ids,
};
#[cfg(feature = "runtime")]
pub use session::{
    PluginResponse, SessionCleanupFn, SessionPrepareFn, call_plugin, plugin_on_event,
    render_plugin, set_session_cleanup, set_session_prepare, start_plugin,
    start_plugin_with_modules, start_registered_plugin, start_registered_plugin_with_grants,
    stop_plugin,
};
#[cfg(feature = "runtime")]
pub use setup::{SetupOptions, setup};
#[cfg(feature = "runtime")]
pub use ui::{UiSetupFn, set_ui_setup};

/// Re-export macros so apps can depend on `fluau` alone for `#[host_module]`.
#[cfg(feature = "runtime")]
pub use fluau_macros::{host_module, host_userdata, HostType, HostUserData};

#[cfg(feature = "stub-gen")]
pub use stub_gen::{
    generate_luau_stubs, emit_luau, parse_directory, parse_source, HostApiModel, ParseError,
};
