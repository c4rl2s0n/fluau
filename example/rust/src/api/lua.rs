// Retired by fluau_codegen — do not `mod` this file.
//
// UI catalog: crate::lua_engine (codegen-owned).
// Call once from #[frb(init)] / process start:
//   let _ = crate::lua_engine::register_ui_catalog();
// Or pass ui_setup: Some(crate::lua_engine::setup_lua_api) to fluau::setup.
// Note: fluau::setup clears UI registration — call register_ui_catalog *after*
// setup when ui_setup is None, or pass ui_setup inside setup.
