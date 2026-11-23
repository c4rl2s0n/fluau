//! Per-plugin HTTP client with cookie jar and permission allowlist.

use lazy_static::lazy_static;
use serde_json::{json, Map, Value};
use std::collections::HashMap;
use std::sync::Mutex;

use super::http;

lazy_static! {
    static ref CLIENTS: Mutex<HashMap<String, HttpClient>> = Mutex::new(HashMap::new());
}

#[derive(Default, Debug)]
pub struct HttpClient {
    cookies: HashMap<String, String>,
    allowlist: Vec<String>,
}

impl HttpClient {
    pub fn set_allowlist(&mut self, allowlist: Vec<String>) {
        self.allowlist = allowlist;
    }

    pub fn request(&mut self, opts: &Value) -> Value {
        let method = opts
            .get("method")
            .and_then(|v| v.as_str())
            .unwrap_or("GET")
            .to_uppercase();
        let url = opts.get("url").and_then(|v| v.as_str()).unwrap_or("");
        let body = opts.get("body");
        let headers = opts.get("headers");

        if !self.allowlist.is_empty() && !http::host_allowed(url, &self.allowlist) {
            return json!({
                "ok": false,
                "status": 403,
                "body": {
                    "error": format!(
                        "host not allowed by plugin httpAllowlist: {}",
                        http::host_of(url).unwrap_or_else(|| url.to_string())
                    )
                }
            });
        }

        let cookie_header = self.cookie_header();
        let mut response = http::request(
            &method,
            url,
            body,
            headers,
            if cookie_header.is_empty() {
                None
            } else {
                Some(&cookie_header)
            },
        );

        self.ingest_set_cookie(&response);

        // Stub login convenience cookie for fake.proton demos.
        if url.contains("fake.proton") && (url.contains("auth") || url.contains("login")) {
            if response.get("ok").and_then(|v| v.as_bool()) == Some(true) {
                let token = response
                    .pointer("/body/token")
                    .and_then(|v| v.as_str())
                    .unwrap_or("stub-session")
                    .to_string();
                self.cookies.insert("session".to_string(), token.clone());
                if let Value::Object(ref mut map) = response {
                    map.insert(
                        "headers".into(),
                        json!({ "set-cookie": [format!("session={token}")] }),
                    );
                }
            }
        }

        if let Value::Object(ref mut map) = response {
            let mut out_headers = match map.remove("headers") {
                Some(Value::Object(h)) => h,
                _ => Map::new(),
            };
            if !self.cookies.is_empty() {
                out_headers.insert("cookie".into(), Value::String(self.cookie_header()));
            }
            map.insert("headers".into(), Value::Object(out_headers));
        }

        response
    }

    fn ingest_set_cookie(&mut self, response: &Value) {
        let Some(headers) = response.get("headers") else {
            return;
        };
        let values = match headers.get("set-cookie") {
            Some(Value::Array(arr)) => arr
                .iter()
                .filter_map(|v| v.as_str())
                .map(|s| s.to_string())
                .collect::<Vec<_>>(),
            Some(Value::String(s)) => vec![s.clone()],
            _ => return,
        };
        for raw in values {
            if let Some((name, rest)) = raw.split_once('=') {
                let value = rest.split(';').next().unwrap_or("").trim();
                if !name.is_empty() {
                    self.cookies
                        .insert(name.trim().to_string(), value.to_string());
                }
            }
        }
    }

    fn cookie_header(&self) -> String {
        self.cookies
            .iter()
            .map(|(k, v)| format!("{k}={v}"))
            .collect::<Vec<_>>()
            .join("; ")
    }
}

pub fn with_client<T>(
    plugin_id: &str,
    f: impl FnOnce(&mut HttpClient) -> T,
) -> Result<T, String> {
    let mut clients = CLIENTS.lock().map_err(|e| e.to_string())?;
    let client = clients.entry(plugin_id.to_string()).or_default();
    Ok(f(client))
}

pub fn configure(plugin_id: &str, allowlist: Vec<String>) -> Result<(), String> {
    with_client(plugin_id, |client| client.set_allowlist(allowlist))?;
    Ok(())
}

pub fn clear_client(plugin_id: &str) {
    if let Ok(mut clients) = CLIENTS.lock() {
        clients.remove(plugin_id);
    }
}
