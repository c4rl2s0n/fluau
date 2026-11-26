//! HTTP transport for plugin host requests.

use std::io::Read;

use serde_json::{json, Value};
use url::Url;

/// Max response body size (large JSON payloads can exceed ureq's default 10 MiB
/// `into_string` cap).
const MAX_BODY_BYTES: u64 = 64 * 1024 * 1024;

/// Perform an HTTP request over the network.
pub fn request(
    method: &str,
    url: &str,
    body: Option<&Value>,
    headers: Option<&Value>,
    cookie_header: Option<&str>,
) -> Value {
    real_request(method, url, body, headers, cookie_header)
}

fn real_request(
    method: &str,
    url: &str,
    body: Option<&Value>,
    headers: Option<&Value>,
    cookie_header: Option<&str>,
) -> Value {
    let method = method.to_uppercase();
    let mut req = match method.as_str() {
        "GET" => ureq::get(url),
        "POST" => ureq::post(url),
        "PUT" => ureq::put(url),
        "DELETE" => ureq::delete(url),
        other => {
            return json!({
                "ok": false,
                "status": 0,
                "body": { "error": format!("unsupported method: {other}") }
            });
        }
    };

    req = req.set("User-Agent", "luatest-plugin/0.1");

    if let Some(Value::Object(map)) = headers {
        for (k, v) in map {
            if let Some(s) = v.as_str() {
                req = req.set(k, s);
            }
        }
    }
    if let Some(cookie) = cookie_header {
        if !cookie.is_empty() {
            req = req.set("Cookie", cookie);
        }
    }

    let result = if matches!(method.as_str(), "POST" | "PUT") {
        let payload = body.cloned().unwrap_or(Value::Null);
        req.send_json(payload)
    } else {
        req.call()
    };

    match result {
        Ok(resp) => {
            let status = resp.status();
            let content_length = resp.header("content-length").map(|s| s.to_string());
            let mut set_cookies = Vec::new();
            for value in resp.all("set-cookie") {
                set_cookies.push(Value::String(value.to_string()));
            }
            match read_body(resp, content_length.as_deref()) {
                Ok(text) => {
                    let parsed_body =
                        serde_json::from_str::<Value>(&text).unwrap_or(Value::String(text));
                    json!({
                        "ok": (200..300).contains(&status),
                        "status": status,
                        "body": parsed_body,
                        "headers": {
                            "set-cookie": set_cookies,
                        }
                    })
                }
                Err(err) => json!({
                    "ok": false,
                    "status": status,
                    "body": { "error": err },
                    "headers": {
                        "set-cookie": set_cookies,
                    }
                }),
            }
        }
        Err(ureq::Error::Status(code, resp)) => {
            let content_length = resp.header("content-length").map(|s| s.to_string());
            match read_body(resp, content_length.as_deref()) {
                Ok(text) => {
                    let parsed_body =
                        serde_json::from_str::<Value>(&text).unwrap_or(Value::String(text));
                    json!({
                        "ok": false,
                        "status": code,
                        "body": parsed_body,
                    })
                }
                Err(err) => json!({
                    "ok": false,
                    "status": code,
                    "body": { "error": err },
                }),
            }
        }
        Err(e) => json!({
            "ok": false,
            "status": 0,
            "body": { "error": e.to_string() }
        }),
    }
}

/// Read response body with an explicit size cap. Never returns Ok("") after a read failure.
fn read_body(resp: ureq::Response, content_length: Option<&str>) -> Result<String, String> {
    if let Some(cl) = content_length {
        if let Ok(n) = cl.parse::<u64>() {
            if n > MAX_BODY_BYTES {
                return Err(format!(
                    "response body Content-Length {n} exceeds limit {MAX_BODY_BYTES} bytes"
                ));
            }
        }
    }

    let mut reader = resp.into_reader().take(MAX_BODY_BYTES + 1);
    let mut buf = Vec::new();
    reader
        .read_to_end(&mut buf)
        .map_err(|e| format!("failed to read response body: {e}"))?;

    if buf.len() as u64 > MAX_BODY_BYTES {
        return Err(format!(
            "response body exceeds limit of {MAX_BODY_BYTES} bytes (read {}+)",
            MAX_BODY_BYTES
        ));
    }

    String::from_utf8(buf).map_err(|e| format!("response body is not valid UTF-8: {e}"))
}

/// Extract hostname for allowlist checks.
pub fn host_of(url: &str) -> Option<String> {
    Url::parse(url)
        .ok()
        .and_then(|u| u.host_str().map(|h| h.to_lowercase()))
}

pub fn host_allowed(url: &str, allowlist: &[String]) -> bool {
    if allowlist.is_empty() {
        return false;
    }
    let Some(host) = host_of(url) else {
        return false;
    };
    allowlist.iter().any(|allowed| {
        let a = allowed.to_lowercase();
        host == a || host.ends_with(&format!(".{a}"))
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn allowlist_matches_host_and_subdomain() {
        let list = vec!["api.example.com".into(), "demo.local".into()];
        assert!(host_allowed("https://api.example.com/v1/items", &list));
        assert!(host_allowed("https://demo.local/auth/login", &list));
        assert!(!host_allowed("https://evil.example/x", &list));
    }
}
