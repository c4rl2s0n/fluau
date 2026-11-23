//! Host handle composed from modular traits.

use std::sync::Arc;

use mlua::{Lua, Result as LuaResult, Table};

use super::crypto_api::HostCrypto;
use super::db_api::HostDb;
use super::http_api::HostHttp;
use super::log_api::HostLog;

/// Cheap-to-clone host handle passed into Lua bindings.
#[derive(Clone, Debug)]
pub struct Host {
    pub plugin_id: Arc<str>,
}

impl Host {
    pub fn new(plugin_id: impl AsRef<str>) -> Self {
        Self {
            plugin_id: Arc::from(plugin_id.as_ref()),
        }
    }

    /// Install all host modules onto a fresh `host` global.
    pub fn inject_into(self, lua: &Lua) -> LuaResult<()> {
        let root: Table = lua.create_table()?;
        HostDb::install_into(&root, self.clone(), lua)?;
        HostHttp::install_into(&root, self.clone(), lua)?;
        HostCrypto::install_into(&root, self.clone(), lua)?;
        HostLog::install_into(&root, self.clone(), lua)?;
        lua.globals().set("host", root)?;
        Ok(())
    }
}
