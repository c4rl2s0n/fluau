# Extending HostAPIs

Host services are the privilege boundary. Add one when plugins need an operation
that must not be implementable in pure Luau: networking policy, storage, crypto,
logging sinks, and similar.

## Approach

1. Implement annotated host traits / UserData in the **app** crate (example:
   `example/rust/src/demo_host/`) with `#[host_module(...)]`.
2. Register via `fluau::setup(SetupOptions { host_apis: … })` — core
   ships an empty registry.
3. Call `PermissionGate::require` / `require_with` on every privileged path;
   register constraint checkers at setup.
4. Rebuild — Luau stubs refresh from `host_apis` in `fluau.yaml` / `build.rs`.

Do **not** put concrete HostAPIs in the core crate. Do **not** change
`LuaPluginBridge` shapes for new surfaces; constraints stay opaque JSON.

Prefer generic host primitives; keep provider-specific protocols in plugin Luau.
