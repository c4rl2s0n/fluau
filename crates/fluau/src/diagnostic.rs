//! Process-level diagnostics for escaped Luau C++ exceptions and soft errors.

use std::cell::RefCell;
use std::ffi::CString;
use std::sync::Once;

thread_local! {
    static CURRENT_PLUGIN_OP: RefCell<Option<CString>> = const { RefCell::new(None) };
}

extern "C" {
    fn fluau_install_terminate_hook();
}

/// Called from the C++ terminate handler (must stay valid while terminate runs).
#[no_mangle]
pub unsafe extern "C" fn fluau_current_plugin_op() -> *const std::os::raw::c_char {
    CURRENT_PLUGIN_OP.with(|slot| match slot.borrow().as_ref() {
        Some(s) => s.as_ptr(),
        None => std::ptr::null(),
    })
}

/// Install the terminate hook once (safe to call repeatedly).
pub fn install_diagnostic_hooks() {
    static ONCE: Once = Once::new();
    ONCE.call_once(|| unsafe {
        fluau_install_terminate_hook();
    });
}

/// RAII scope that labels the current plugin operation for terminate diagnostics.
pub struct PluginOpGuard {
    prev: Option<CString>,
}

impl PluginOpGuard {
    pub fn enter(plugin_id: &str, op: &str) -> Self {
        let label = format!("[{plugin_id}] {op}");
        let c = CString::new(label).unwrap_or_else(|_| CString::new("fluau op").unwrap());
        let prev = CURRENT_PLUGIN_OP.with(|slot| slot.borrow_mut().replace(c));
        Self { prev }
    }
}

impl Drop for PluginOpGuard {
    fn drop(&mut self) {
        let prev = self.prev.take();
        CURRENT_PLUGIN_OP.with(|slot| {
            *slot.borrow_mut() = prev;
        });
    }
}

/// Format a plugin-scoped error, log it, and return the string for `Err(...)`.
pub fn plugin_err(plugin_id: &str, op: &str, e: impl std::fmt::Display) -> String {
    let msg = format!("[{plugin_id}] {op}: {e}");
    eprintln!("fluau: {msg}");
    msg
}
