//! Host handle composed from modular traits.

use std::sync::Arc;

use mlua::{Lua, Result as LuaResult};

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

    /// Install all builtin host modules onto a fresh `host` global (ungated; tests only).
    pub fn inject_into(self, lua: &Lua) -> LuaResult<()> {
        let all: Vec<String> = super::api_registry::known_api_ids()
            .into_iter()
            .map(|s| s.to_string())
            .collect();
        super::api_registry::inject_granted(lua, self, &all)
    }
}
