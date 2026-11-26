//! Pluggable UI catalog installer (app/codegen provides builders).

use lazy_static::lazy_static;
use mlua::{Lua, Result as LuaResult};
use std::sync::Mutex;

pub type UiSetupFn = fn(&Lua) -> LuaResult<()>;

lazy_static! {
    static ref UI_SETUP: Mutex<Option<UiSetupFn>> = Mutex::new(None);
}

pub fn set_ui_setup(f: UiSetupFn) -> Result<(), String> {
    let mut slot = UI_SETUP.lock().map_err(|e| e.to_string())?;
    *slot = Some(f);
    Ok(())
}

pub fn clear_ui_setup() {
    if let Ok(mut slot) = UI_SETUP.lock() {
        *slot = None;
    }
}

pub fn install_ui(lua: &Lua) -> LuaResult<()> {
    crate::actions::ensure_registry(lua)?;
    let slot = UI_SETUP.lock().expect("ui setup lock");
    if let Some(f) = *slot {
        f(lua)?;
    } else {
        // Empty catalog: still expose an empty `ui` table.
        let ui = lua.create_table()?;
        lua.globals().set("ui", ui)?;
    }
    // Always attach `ui.action` (session-owned function callbacks).
    crate::actions::install_ui_helpers(lua)?;
    Ok(())
}
