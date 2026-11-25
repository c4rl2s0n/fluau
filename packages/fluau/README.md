# fluau

Sandboxed **Luau** plugins for Flutter. Plugins draw from a **host-owned** UI
catalog, talk to the app through gated host services, and can expose typed
capabilities back to Dart.

## Prerequisites

fluau does **not** include a Flutter↔Rust bridge. You need:

1. An existing [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/)
   app (or another Flutter–Rust bridge). The example pins **2.13.0**.
2. The Rust runtime crate from this monorepo (`lua_plugin_core`, git/path until
   published on crates.io under the fluau family).

Bridge-from-zero is covered by FRB’s documentation, not by fluau.

## Install

```yaml
dependencies:
  fluau: ^0.1.0
```

## Bootstrap

After FRB works in your app, add `fluau.yaml` and stamp glue:

```bash
dart run fluau:bootstrap
flutter_rust_bridge_codegen generate
```

Then:

```dart
await RustLib.init();
LuaPluginBridge.bind(FrbLuaPluginBridge());
await PluginRegistryLoader.registerPackages([...]);
// Pass your catalog: LuaPlugin(..., buildWidget: YourRegistry.buildFromMap)
```

## What this package provides

- `LuaPluginBridge` + `dart run fluau:bootstrap` (FRB façade + Dart adapter)
- Package YAML loader, grant UI helpers, `PluginGrantStore`
- Annotations (`@LuaWidget`, `@LuaCapability`, …) and session host widgets
- `LuaWidgetInterface` — **no** default widgets ship here

## What the app owns

- FRB (or equivalent) and the Rust core dependency
- Host APIs and the UI catalog (codegen)
- Grant persistence — `MemoryPluginGrantStore` is ephemeral; implement
  `PluginGrantStore` or use `JsonFilePluginGrantStore` as a starting point

## License

MIT
