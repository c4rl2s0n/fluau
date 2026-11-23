//! Builtin host API registry: metadata + install hooks.
//!
//! Session inject loops this registry filtered by [`super::permissions::PermissionGate`]
//! grants — no hard-coded if-ladder in `session.rs`.

use mlua::{Lua, Result as LuaResult, Table};

use super::crypto_api::HostCrypto;
use super::db_api::HostDb;
use super::facade::Host;
use super::http_api::HostHttp;
use super::log_api::HostLog;

/// Static description of a host module available to plugins.
#[derive(Clone, Copy)]
pub struct HostApiEntry {
    pub id: &'static str,
    pub path: &'static str,
    pub summary: &'static str,
    pub install: fn(&Table, Host, &Lua) -> LuaResult<()>,
}

fn install_db(root: &Table, host: Host, lua: &Lua) -> LuaResult<()> {
    HostDb::install_into(root, host, lua)
}

fn install_http(root: &Table, host: Host, lua: &Lua) -> LuaResult<()> {
    HostHttp::install_into(root, host, lua)
}

fn install_crypto(root: &Table, host: Host, lua: &Lua) -> LuaResult<()> {
    HostCrypto::install_into(root, host, lua)
}

fn install_log(root: &Table, host: Host, lua: &Lua) -> LuaResult<()> {
    HostLog::install_into(root, host, lua)
}

/// Builtin host APIs shipped with the framework.
pub fn builtin_host_apis() -> &'static [HostApiEntry] {
    &[
        HostApiEntry {
            id: "db",
            path: "db",
            summary: "Per-plugin key-value storage",
            install: install_db,
        },
        HostApiEntry {
            id: "http",
            path: "http",
            summary: "Outbound HTTP to allowlisted domains",
            install: install_http,
        },
        HostApiEntry {
            id: "crypto",
            path: "crypto",
            summary: "Generic cryptographic primitives",
            install: install_crypto,
        },
        HostApiEntry {
            id: "log",
            path: "log",
            summary: "Diagnostic logging to the host",
            install: install_log,
        },
    ]
}

pub fn find_builtin(id: &str) -> Option<&'static HostApiEntry> {
    builtin_host_apis().iter().find(|e| e.id == id)
}

pub fn known_api_ids() -> Vec<&'static str> {
    builtin_host_apis().iter().map(|e| e.id).collect()
}

/// Install every granted builtin onto `host` root.
pub fn inject_granted(lua: &Lua, host: Host, granted_apis: &[String]) -> LuaResult<()> {
    let root = lua.create_table()?;
    for entry in builtin_host_apis() {
        if granted_apis.iter().any(|g| g == entry.id) {
            (entry.install)(&root, host.clone(), lua)?;
        }
    }
    lua.globals().set("host", root)?;
    Ok(())
}
