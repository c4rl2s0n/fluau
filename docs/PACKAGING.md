# Packaging: tools-only core, app owns surfaces + FRB

## Layout

| Path | Role |
|------|------|
| `crates/lua_plugin_core` | rlib runtime (session, sandbox, registry, PermissionGate, macros). **No** demo HostAPIs or UI catalog. |
| `crates/host_api_macros` / `host_api_meta` | `#[host_module]` + Luau stub emission |
| `packages/lua_plugin` | Dart tools: `LuaPluginBridge`, generic DTOs, grants, YAML loader, `@LuaWidget` |
| `example/` | Flutter + single `cdylib` RustLib: registers demo HostAPIs/widgets, owns FRB, stamps bridge |

Full “bootstrap FRB from zero” (first `flutter_rust_bridge.yaml` / Native Assets hook) is **out of scope**. Start from an existing FRB app (see [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/)).

The **example** uses FRB’s **Native Assets** backend (`hook/build.dart` + `flutter_rust_bridge_hooks`). Downstream apps own their FRB integration backend (Native Assets or Cargokit) and Android Gradle/AGP versions; the Lua packages do not pin either.

## FRB version pin

Match the app’s `flutter_rust_bridge` / codegen CLI to the version in `example/lua_plugin.yaml` (`frb_version`) and `example/pubspec.yaml` / `example/rust/Cargo.toml`. Current pin: **2.13.0**.

## Integration (existing FRB app)

1. Add Cargo deps on `lua_plugin_core` (+ macros).
2. Copy / create `lua_plugin.yaml` (paths for stamped Rust API module + Dart adapter).
3. Implement HostAPIs and call `lua_plugin_core::setup(...)` once at process start (see `example/rust/src/demo_host`).
4. Stamp glue:

```bash
cd example
dart run ../packages/lua_plugin/bin/bootstrap.dart
flutter_rust_bridge_codegen generate
# optional: dart run ../packages/lua_plugin/bin/bootstrap.dart --generate-frb
```

5. Flutter:

```dart
await RustLib.init();
LuaPluginBridge.bind(FrbLuaPluginBridge()); // stamped adapter
await PluginRegistryLoader.registerPackages([...]);
// LuaPlugin(pluginId: '...')
```

## Extending HostAPIs

1. Add a `#[host_module]` trait + install fn in the **app** crate (not core).
2. Register it in `setup` / `SetupOptions.host_apis` (+ intent handler / constraint checker if needed).
3. Rebuild — Luau stubs refresh from `host_apis` path in `lua_plugin.yaml` / `build.rs`.
4. **Do not** change `LuaPluginBridge` or FRB DTO shapes; constraints stay opaque JSON.

## Extending UI (`@LuaWidget`)

1. Annotate widgets in the app or a package the codegen scans.
2. Point codegen output / stub dirs at paths from `lua_plugin.yaml` (`stubs.ui_d_luau`).
3. Register the UI setup hook via `SetupOptions.ui_setup` (example uses generated `lua_engine::setup_lua_api`).

## Bridge contract

| Traffic | Shape |
|---------|--------|
| UI snapshot, events, fields, capability args/results | `String` JSON |
| Manifest / grants | Generic DTOs in `packages/lua_plugin` (`HostApiPermissionDto`, …) |

Adding HostApis or widgets does **not** require new bridge methods.

Typed **capability** facades (`@LuaCapability` / `@LuaCapabilityDto`) live in the app; codegen fills `callPlugin` + `fromJson` without changing the bridge. See [CAPABILITIES.md](CAPABILITIES.md).
