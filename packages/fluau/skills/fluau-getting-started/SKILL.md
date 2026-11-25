---
name: fluau-getting-started
description: >-
  Use when onboarding to fluau, explaining prerequisites, or helping a user run
  their first host/plugin setup with Flutter and Luau.
---

# fluau getting started

## Guidelines

* Always treat a Flutter–Rust bridge (e.g. flutter_rust_bridge) as **required**. Do not invent FRB-from-zero steps; link to FRB docs.
* Always depend on both the Dart package `fluau` (pub.dev) and the Rust crate `fluau` (crates.io). Patch versions need not match within `0.1` (e.g. Dart `^0.1.9` + crates `0.1.0` is fine).
* Prefer the published docs for deep dives: [Getting started](https://github.com/c4rl2s0n/fluau/blob/main/docs/GETTING_STARTED.md).
* For a runnable demo, clone the monorepo and run the `example/` app — do not assume widgets ship inside the Dart package.
* After upgrading `fluau`, re-run `dart run skills@ get` so agent skills match the package.

## Examples

### Dependencies

```yaml
dependencies:
  fluau: ^0.1.9

dev_dependencies:
  fluau_codegen: ^0.1.5
```

```toml
[dependencies]
fluau = "0.1"

[build-dependencies]
fluau = { version = "0.1", default-features = false, features = ["stub-gen"] }
```

### End-to-end checklist

1. FRB app already runs (`RustLib.init()` works).
2. Add Dart `fluau` + Cargo `fluau = "0.1"` (+ stub-gen build-dep).
3. Add `dev_dependencies: fluau_codegen`.
4. `dart run fluau:bootstrap` → import stamped `lib/fluau/fluau_bridge.g.dart` → after `WidgetsFlutterBinding.ensureInitialized()` and `RustLib.init()`, `LuaPluginBridge.bind(FrbLuaPluginBridge())` (never `bind(instance)`).
5. Annotate `StatelessWidget`s with `@LuaWidget` (ctor params = Lua API) → `dart run fluau_codegen` (serializers land in `dart.lua_root`, default `lib/fluau/`) → import `widget_serializers.g.dart` → wire `ui_setup: Some(lua_engine::setup_lua_api)` and `buildWidget: LuaWidgetRegistry.buildFromMap`.
6. Plugin under `assets/plugins/...` → list in `pubspec.yaml` assets → `registerPackages` → `LuaPlugin(...)`.

### Next skills

* Host integration → `fluau-integrate-host`
* UI catalog / codegen → `fluau-ui-catalog`
* Writing a plugin → `fluau-write-plugin`
* Regen → `fluau-regen`
