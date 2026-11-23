//! `host.log` module — trait contract + Host impl.

use host_api_macros::host_module;

use super::facade::Host;
use super::permissions::PermissionGate;

#[host_module(
    path = "log",
    permission = "log",
    summary = "Diagnostic logging to the host"
)]
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
        if PermissionGate::require(&self.plugin_id, "log").is_err() {
            return;
        }
        eprintln!("[debug] [{}] {message}", self.plugin_id);
    }

    fn info(&self, message: String) {
        if PermissionGate::require(&self.plugin_id, "log").is_err() {
            return;
        }
        eprintln!("[info] [{}] {message}", self.plugin_id);
    }

    fn warn(&self, message: String) {
        if PermissionGate::require(&self.plugin_id, "log").is_err() {
            return;
        }
        eprintln!("[warn] [{}] {message}", self.plugin_id);
    }

    fn error(&self, message: String) {
        if PermissionGate::require(&self.plugin_id, "log").is_err() {
            return;
        }
        eprintln!("[error] [{}] {message}", self.plugin_id);
    }
}
