//! `host.log` module — trait contract + Host impl.

use host_api_macros::host_module;

use super::facade::Host;

#[host_module(path = "log")]
pub trait HostLog {
    #[lua(name = "debug")]
    fn debug(&self, message: String);

    #[lua(name = "info")]
    fn info(&self, message: String);

    #[lua(name = "warn")]
    fn warn(&self, message: String);

    #[lua(name = "error")]
    fn error(&self, message: String);
}

impl HostLog for Host {
    fn debug(&self, message: String) {
        eprintln!("[debug] [{}] {message}", self.plugin_id);
    }

    fn info(&self, message: String) {
        eprintln!("[info] [{}] {message}", self.plugin_id);
    }

    fn warn(&self, message: String) {
        eprintln!("[warn] [{}] {message}", self.plugin_id);
    }

    fn error(&self, message: String) {
        eprintln!("[error] [{}] {message}", self.plugin_id);
    }
}
