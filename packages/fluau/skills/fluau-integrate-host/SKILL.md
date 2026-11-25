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
* Pass `ui_setup: Some(lua_engine::setup_lua_api)` (from `fluau_codegen`). Without it, Lua gets an **empty** `ui` table.
* `dart run fluau:bootstrap` stamps `lib/fluau/fluau_bridge.g.dart` (via `dart.lua_root`) → import `package:<pubspec.name>/fluau/fluau_bridge.g.dart`. Always `LuaPluginBridge.bind(FrbLuaPluginBridge())` after `RustLib.init()`. **Never** `bind(LuaPluginBridge.instance)` — that throws `StateError`.
* Always pass a host-owned `buildWidget` into `LuaPlugin` / `LuaPluginView` — fluau ships **no** default UI catalog; import `lib/fluau/widget_serializers.g.dart` and use generated `LuaWidgetRegistry.buildFromMap`.
* Always persist permission decisions with a `PluginGrantStore` (memory is ephemeral; prefer a custom or file store for real apps).
* Use `dart run fluau:bootstrap` to stamp glue (`fluau.yaml` optional). Then run `flutter_rust_bridge_codegen generate` when FRB APIs change.
* For `build.rs` stub emission, add crates.io `fluau` with `stub-gen` in `build-dependencies`.
* Version pairing: Dart `fluau: ^0.1.8` + crates `fluau = "0.1"` (crates.io may still be 0.1.0) is supported — patch numbers need not match.

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
import 'package:my_app/fluau/fluau_bridge.g.dart'; // stamped by fluau:bootstrap

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init(); // runs #[frb(init)] → fluau::setup on the Rust side
  LuaPluginBridge.bind(FrbLuaPluginBridge()); // never bind(LuaPluginBridge.instance)
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
