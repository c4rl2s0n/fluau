---
name: fluau-integrate-host
description: >-
  Use when embedding fluau in an existing Flutter–Rust bridge app: bootstrap,
  bind LuaPluginBridge, register packages, and wire LuaPlugin.
---

# Integrate fluau into a host

## Guidelines

* Always start from an **existing** FRB (or equivalent) app. Do not scaffold FRB from zero here.
* Always call `LuaPluginBridge.bind(...)` after `RustLib.init()` (or your bridge init).
* Always pass a host-owned `buildWidget` into `LuaPlugin` / `LuaPluginView` — fluau ships **no** default UI catalog.
* Always persist permission decisions with a `PluginGrantStore` (memory is ephemeral; prefer a custom or file store for real apps).
* Use `dart run fluau:bootstrap` to stamp the FRB façade + Dart adapter (`fluau.yaml` is optional; add one to set `frb_plugin_import` / paths). Then run `flutter_rust_bridge_codegen generate` when FRB APIs change.
* Rust: depend on crates.io `fluau` (default `runtime`); use `stub-gen` in `build-dependencies` for `host.d.luau` emission.

Docs: [Integration](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/INTEGRATION.md),
[fluau.yaml](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/FLUAU_YAML.md),
[UI catalog](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/UI_CATALOG.md),
[Plugin permissions](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/PLUGIN_PERMISSIONS.md).

## Examples

### Bootstrap and bind

```bash
dart run fluau:bootstrap
flutter_rust_bridge_codegen generate
```

```dart
import 'package:fluau/fluau.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  LuaPluginBridge.bind(FrbLuaPluginBridge()); // stamped adapter
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
