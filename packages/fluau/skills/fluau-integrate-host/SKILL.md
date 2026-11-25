---
name: fluau-integrate-host
description: >-
  Use when embedding fluau in an existing Flutter–Rust bridge app: bootstrap,
  bind LuaPluginBridge, register packages, and wire LuaPlugin.
---

# Integrate fluau into a host

## Guidelines

* Always start from an **existing** FRB (or equivalent) app. Do not scaffold FRB from zero here.
* Call `fluau::setup(SetupOptions { ... })` **once from Rust** at process start (before plugin sessions). It is **not** FRB-exported — Dart never calls `setup()`. Typical pattern: `#[frb(init)]` hook → `ensure_runtime()` → `setup(...)`, which FRB runs during `RustLib.init()`.
* Pass `ui_setup: Some(lua_engine::setup_lua_api)` (generated) so Lua sessions get the host UI catalog.
* Always call `LuaPluginBridge.bind(FrbLuaPluginBridge())` after `RustLib.init()`. `LuaPluginBridge.instance` is **not** a stub: unbound it throws `StateError`; after bind it is the stamped FRB adapter.
* Always pass a host-owned `buildWidget` into `LuaPlugin` / `LuaPluginView` — fluau ships **no** default UI catalog.
* Always persist permission decisions with a `PluginGrantStore` (memory is ephemeral; prefer a custom or file store for real apps).
* Use `dart run fluau:bootstrap` to stamp `src/api/fluau.rs`, register it in `api/mod.rs`, add `fluau` to Cargo.toml if missing, and stamp the Dart adapter (import inferred from `pubspec.yaml`). `fluau.yaml` is optional for path overrides. Then run `flutter_rust_bridge_codegen generate` when FRB APIs change.
* For `build.rs` stub emission, add crates.io `fluau` with `stub-gen` in `build-dependencies`.

Docs: [Integration](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/INTEGRATION.md),
[fluau.yaml](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/FLUAU_YAML.md),
[UI catalog](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/UI_CATALOG.md),
[Plugin permissions](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/PLUGIN_PERMISSIONS.md).

## Examples

### Rust runtime setup (not FRB-exported)

```rust
// Called from #[frb(init)] during RustLib.init(), or an equivalent Once guard.
fluau::setup(SetupOptions {
    host_apis: vec![/* ... */],
    intent_handlers: vec![/* ... */],
    constraint_checkers: vec![/* ... */],
    ui_setup: Some(crate::lua_engine::setup_lua_api),
})?;
```

### Bootstrap and bind

```bash
dart run fluau:bootstrap
flutter_rust_bridge_codegen generate
```

```dart
import 'package:fluau/fluau.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(); // runs #[frb(init)] → fluau::setup on the Rust side
  LuaPluginBridge.bind(FrbLuaPluginBridge()); // required; instance is not a no-op stub
  await PluginRegistryLoader.registerPackages(const [
    'assets/plugins/my_plugin',
  ]);
  runApp(const MyApp());
}
```

### Render a registered plugin

```dart
LuaPlugin(
  pluginId: 'my-plugin',
  grants: activeGrants,
  buildWidget: MyWidgetRegistry.buildFromMap,
  onProvideResult: (result) { /* ... */ },
);
```
