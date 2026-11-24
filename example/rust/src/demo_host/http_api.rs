//! `host.http` module — trait contract, Host impl, and HttpClient UserData.

use std::collections::HashMap;
use std::sync::{Arc, Mutex};

use host_api_macros::{host_module, host_userdata, HostUserData};
use serde_json::{json, Map, Value as JsonValue};

use lua_plugin_core::Host;
use super::http_client::{self, HttpClient as HttpClientState};
use lua_plugin_core::{PermissionGate, PermissionUse};
use super::types::{HttpRequestOpts, HttpResponse};

#[host_module(
    path = "http",
    permission = "http",
    summary = "Outbound HTTP to allowlisted domains"
)]
pub trait HostHttp {
    /// Shared per-plugin HTTP session (cookie jar).
    #[lua(name = "client")]
    fn client(&self) -> HttpClient;

    /// Convenience request on the default per-plugin session.
    #[lua(name = "request")]
    fn request(&self, opts: HttpRequestOpts) -> HttpResponse;
}

impl HostHttp for Host {
    fn client(&self) -> HttpClient {
        HttpClient::shared(self.plugin_id.clone())
    }

    fn request(&self, opts: HttpRequestOpts) -> HttpResponse {
        HttpClient::shared(self.plugin_id.clone()).request(opts)
    }
}

/// Lua-visible HTTP client handle (UserData).
#[derive(Clone, Debug, HostUserData)]
pub struct HttpClient {
    plugin_id: Arc<str>,
    /// `None` → use the process-wide per-plugin client; `Some` → isolated jar.
    local: Option<Arc<Mutex<HttpClientState>>>,
}

impl HttpClient {
    pub fn shared(plugin_id: Arc<str>) -> Self {
        Self {
            plugin_id,
            local: None,
        }
    }

    pub fn isolated(plugin_id: Arc<str>, allowlist: Vec<String>) -> Self {
        let mut client = HttpClientState::default();
        client.set_allowlist(allowlist);
        Self {
            plugin_id,
            local: Some(Arc::new(Mutex::new(client))),
        }
    }
}

#[host_userdata]
impl HttpClient {
    #[lua(name = "request")]
    pub fn request(&self, opts: HttpRequestOpts) -> HttpResponse {
        if let Err(e) = PermissionGate::require_with(
            &self.plugin_id,
            "http",
            &PermissionUse::Context(json!({ "url": opts.url.clone() })),
        ) {
            return HttpResponse {
                ok: false,
                status: 403,
                body: Some(json!({ "error": e })),
                headers: None,
            };
        }
        let opts_json = opts_to_json(&opts);
        let response = if let Some(local) = &self.local {
            let mut guard = local.lock().expect("http client lock");
            guard.request_unchecked(&opts_json)
        } else {
            http_client::with_client(&self.plugin_id, |client| {
                client.request_unchecked(&opts_json)
            })
            .unwrap_or_else(|e| {
                json!({
                    "ok": false,
                    "status": 500,
                    "body": { "error": e }
                })
            })
        };
        json_to_http_response(response)
    }
}

fn opts_to_json(opts: &HttpRequestOpts) -> JsonValue {
    let mut map = Map::new();
    if let Some(m) = &opts.method {
        map.insert("method".into(), JsonValue::String(m.clone()));
    }
    map.insert("url".into(), JsonValue::String(opts.url.clone()));
    if let Some(b) = &opts.body {
        map.insert("body".into(), b.clone());
    }
    if let Some(h) = &opts.headers {
        let mut headers = Map::new();
        for (k, v) in h {
            headers.insert(k.clone(), JsonValue::String(v.clone()));
        }
        map.insert("headers".into(), JsonValue::Object(headers));
    }
    JsonValue::Object(map)
}

fn json_to_http_response(value: JsonValue) -> HttpResponse {
    let ok = value
        .get("ok")
        .and_then(|v| v.as_bool())
        .unwrap_or(false);
    let status = value
        .get("status")
        .and_then(|v| v.as_i64())
        .unwrap_or(0);
    let body = value.get("body").cloned();
    let headers = value.get("headers").and_then(|h| {
        let obj = h.as_object()?;
        let mut map = HashMap::new();
        for (k, v) in obj {
            map.insert(k.clone(), v.clone());
        }
        Some(map)
    });
    HttpResponse {
        ok,
        status,
        body,
        headers,
    }
}
