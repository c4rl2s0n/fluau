//! `host.db` module — trait contract + Host impl.

use host_api_macros::host_module;

use super::db;
use super::facade::Host;

#[host_module(path = "db")]
pub trait HostDb {
    #[lua(name = "get")]
    fn get(&self, key: String) -> Option<String>;

    #[lua(name = "set")]
    fn set(&self, key: String, value: String) -> Result<(), String>;
}

impl HostDb for Host {
    fn get(&self, key: String) -> Option<String> {
        db::get(&self.plugin_id, &key).ok().flatten()
    }

    fn set(&self, key: String, value: String) -> Result<(), String> {
        db::set(&self.plugin_id, &key, &value)
    }
}
