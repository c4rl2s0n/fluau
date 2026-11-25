# Host integration

Integrate fluau into an app that **already** has a Flutter–Rust bridge. Creating
FRB from zero is covered by the
[flutter_rust_bridge docs](https://cjycode.com/flutter_rust_bridge/), not here.

## Layout

| Piece | Role |
|-------|------|
| Rust [`fluau`](https://crates.io/crates/fluau) (+ `fluau_macros`) | Session, sandbox, PermissionGate, empty HostApi registry; `stub-gen` for build.rs |
| Dart `fluau` | Bridge interface, permission store, YAML loader, annotations |
| Your app | FRB, HostAPIs, UI catalog, `fluau.yaml`, stamped glue |

The example uses FRB’s Native Assets backend. Downstream apps own their FRB
backend (Native Assets or Cargokit) and Android Gradle/AGP versions.

## FRB version pin

Match the app’s `flutter_rust_bridge` / codegen CLI to `fluau.yaml` (`frb_version`)
and the example pin: **2.13.0**.

## Steps

1. Add Cargo deps on `fluau` (default `runtime` feature). For `build.rs` stub
   generation: `fluau` with `default-features = false, features = ["stub-gen"]`.
2. Create `fluau.yaml` (paths for stamped Rust API module + Dart adapter).
3. Implement HostAPIs and call `fluau::setup(...)` once at process start
   (see `example/rust/src/demo_host`).
4. Stamp glue and bind (see below).

<!-- fluau:include-begin id="bootstrap-bind" -->
### Bootstrap and bind

After FRB works in your app, add `fluau.yaml` and stamp glue:

```bash
dart run fluau:bootstrap
flutter_rust_bridge_codegen generate
# optional: dart run fluau:bootstrap --generate-frb
```

Then:

```dart
await RustLib.init();
LuaPluginBridge.bind(FrbLuaPluginBridge()); // stamped adapter
await PluginRegistryLoader.registerPackages([...]);
// LuaPlugin(pluginId: '...', buildWidget: YourRegistry.buildFromMap, ...)
```
<!-- fluau:include-end id="bootstrap-bind" -->

## Bridge contract

| Traffic | Shape |
|---------|--------|
| UI snapshot, events, fields, capability args/results | `String` JSON |
| Manifest / permission DTOs | Generic DTOs in `fluau` |

Adding HostApis or widgets does **not** require new bridge methods.

Also set up a [UI catalog](UI_CATALOG.md) and a [permission store](PLUGIN_PERMISSIONS.md).
