//! One-shot process setup for the Luau plugin runtime.

use crate::diagnostic;
use crate::host::{self, api_registry::HostApiEntry, permissions::ConstraintChecker};
use crate::ui::{self, UiSetupFn};

/// Options for [`setup`].
#[derive(Default)]
pub struct SetupOptions {
    pub host_apis: Vec<HostApiEntry>,
    pub intent_handlers: Vec<(String, host::IntentHandler)>,
    pub constraint_checkers: Vec<(String, ConstraintChecker)>,
    pub ui_setup: Option<UiSetupFn>,
}

/// Configure the runtime: register HostApis, intent handlers, constraint checkers, UI catalog.
///
/// Call once at process start from the app (before starting plugin sessions).
/// Also installs the process terminate hook so escaped Luau C++ exceptions print
/// `what()` (and the current plugin/op) instead of only the type name.
pub fn setup(opts: SetupOptions) -> Result<(), String> {
    diagnostic::install_diagnostic_hooks();

    host::api_registry::clear_host_apis();
    host::clear_intent_handlers();
    host::PermissionGate::clear_constraint_checkers();
    ui::clear_ui_setup();

    host::api_registry::set_host_apis(opts.host_apis)?;
    for (ty, handler) in opts.intent_handlers {
        host::register_intent_handler(&ty, handler)?;
    }
    for (api, checker) in opts.constraint_checkers {
        host::PermissionGate::set_constraint_checker(&api, checker)?;
    }
    if let Some(ui) = opts.ui_setup {
        ui::set_ui_setup(ui)?;
    }
    Ok(())
}
