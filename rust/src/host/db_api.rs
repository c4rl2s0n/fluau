//! `host.db` module — trait contract + Host impl.

use host_api_macros::host_module;

use super::db;
use super::facade::Host;
use super::permissions::PermissionGate;

#[host_module(
    path = "db",
    permission = "db",
    summary = "Per-plugin key-value storage"
)]
pub trait HostDb {
    #[lua(name = "get")]
    fn get(&self, key: String) -> Option<String>;

    #[lua(name = "set")]
    fn set(&self, key: String, value: String) -> Result<(), String>;
}

impl HostDb for Host {
    fn get(&self, key: String) -> Option<String> {
        PermissionGate::require(&self.plugin_id, "db").ok()?;
        db::get(&self.plugin_id, &key).ok().flatten()
    }

    fn set(&self, key: String, value: String) -> Result<(), String> {
        PermissionGate::require(&self.plugin_id, "db")?;
        db::set(&self.plugin_id, &key, &value)
    }
}
