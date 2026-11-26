# Changelog

## 0.1.2

- Session-scoped UI action registry: Lua callback props may be functions;
  reserved `{ type = "action", id }` events are auto-dispatched. Staging →
  commit around successful `render()`; `ui.action(fn, extra?)` helper.

## 0.1.1

- Re-export `mlua` and `serde_json` under the `runtime` feature (`fluau::mlua`,
  `fluau::serde_json`) for generated UI catalogs and HostAPIs.
- Richer plugin session errors: `[plugin_id] op: …` with mlua message/traceback,
  script chunk name `@plugin_id`, and `eprintln` logging on soft failures.
- Session APIs no longer hold the sessions mutex across Lua calls.
- `setup` (and first session entry) installs a C++ terminate hook so escaped
  Luau `lua_exception` prints `what()` and the current plugin/op.

## 0.1.0

- Initial crates.io release.
