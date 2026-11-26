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

Match the app’s `flutter_rust_bridge` / codegen CLI to the example pin (**2.13.0**),
and to `frb_version` in [`fluau.yaml`](FLUAU_YAML.md) when you set one.

## Steps

1. Add the Dart `fluau` package. Bootstrap adds `fluau = "0.1"` to
   `Cargo.toml` when missing (default `runtime` feature). For `build.rs` stub
   generation, also depend on `fluau` with
   `default-features = false, features = ["stub-gen"]`.
2. Optionally create [`fluau.yaml`](FLUAU_YAML.md) when stamp paths differ from
   bootstrap defaults (`src/api/fluau.rs`, inferred FRB import).
3. Implement HostAPIs and call `fluau::setup(...)` once at process start
   (see Runtime setup below; example lives in `example/rust/src/demo_host`).
4. Stamp glue and bind (see below).

## Runtime setup

`fluau::setup(SetupOptions { ... })` is **Rust-only** — it is not FRB-exported
and Dart never calls it. Call it once before starting plugin sessions.

**HostAPIs vs UI catalog stay separable.** HostAPIs change rarely; the UI module
regenerates often. Prefer one `#[frb(init)]` with either:

```rust
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    // After setup with ui_setup: None, or when you only need the catalog:
    let _ = crate::lua_engine::register_ui_catalog();
}
```

or pass `ui_setup: Some(crate::lua_engine::setup_lua_api)` inside `fluau::setup`
(then skip `register_ui_catalog`). `setup` **clears** UI first — if
`ui_setup` is `None`, call `register_ui_catalog()` **after** `setup`.

Without registration, Lua gets an **empty** `ui` table — plugins fail on
`ui.Column` / etc. Run [`fluau_codegen`](../codegen/WHEN_TO_RUN.md) then wire
the one-liner (or `ui_setup`). See [UI catalog](UI_CATALOG.md) for the
Lua→JSON→Widget path.

In the example, a `#[frb(init)]` hook runs `ensure_runtime()` during
`RustLib.init()`, which calls `setup` (with `ui_setup`) behind a `Once`.
Plugin FRB entry points may call the same `ensure` again; it stays idempotent.

`dart run fluau:bootstrap` stamps `lib/fluau/fluau_bridge.g.dart` by default
(override via `fluau.yaml` `dart.lua_root` / `dart.bridge_adapter`). Import
`package:<pubspec.name>/fluau/fluau_bridge.g.dart` and bind **that** adapter:

`LuaPluginBridge.bind(FrbLuaPluginBridge())`. Never
`bind(LuaPluginBridge.instance)` — that reads the unbound singleton and throws
`StateError`. After a correct bind, `instance` forwards to FRB.

**Versions:** Dart `fluau: ^0.1.13` with crates.io `fluau = "0.1"` (**0.1.1+**
for `fluau::mlua` / `fluau::serde_json` re-exports) is supported — patch
numbers need not match within `0.1`. Use those re-exports from generated
`lua_engine` and optional HostAPI code; run `cargo update -p fluau` if a
lockfile still pins 0.1.0.

<!-- fluau:include-begin id="bootstrap-bind" -->
### Bootstrap and bind

After FRB works in your app, stamp glue (`fluau.yaml` is optional; add one to
override stamp paths):

```bash
dart run fluau:bootstrap
flutter_rust_bridge_codegen generate
# optional: dart run fluau:bootstrap --generate-frb
```

Then:

```dart
WidgetsFlutterBinding.ensureInitialized();
await RustLib.init(); // runs #[frb(init)] → fluau::setup on the Rust side
LuaPluginBridge.bind(FrbLuaPluginBridge()); // stamped lib/fluau/fluau_bridge.g.dart
await PluginRegistryLoader.registerPackages([...]);
// LuaPlugin(pluginId: '...', buildWidget: LuaWidgetRegistry.buildFromMap, ...)
```
<!-- fluau:include-end id="bootstrap-bind" -->

## Bridge contract

| Traffic | Shape |
|---------|--------|
| UI snapshot, events, fields, capability args/results | `String` JSON |
| Manifest / permission DTOs | Generic DTOs in `fluau` |

Adding HostApis or widgets does **not** require new bridge methods.

Config reference: [FLUAU_YAML.md](FLUAU_YAML.md). Also set up a
[UI catalog](UI_CATALOG.md) and a [permission store](PLUGIN_PERMISSIONS.md).
