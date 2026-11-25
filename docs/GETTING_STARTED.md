# Getting started

fluau lets a Flutter app host sandboxed Luau plugins. Plugins render UI from a
**host-owned catalog**, call gated host services, and may expose typed
capabilities back to Dart.

## Prerequisite: a Flutter–Rust bridge

fluau runs Luau in Rust. A Flutter↔Rust bridge is **required**. This package
does not create one for you.

Use [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) (the example
pins **2.13.0**) or another bridge you already maintain. Follow FRB’s own docs
to bootstrap an app from zero; then come back here to add fluau.

You also need the Rust runtime (`lua_plugin_core` in this repo — git/path until
published on crates.io as part of the fluau family).

## Track 1: Try the example

From the repo:

```bash
cd example
flutter pub get
flutter run
```

Pick **fake VPN** or **Proton VPN**, review the permission sheet, and interact
with the plugin UI. Grants in the example persist via `JsonFilePluginGrantStore`
under the system temp directory.

Optional — refresh stamped FRB/Dart glue (only needed after bridge API changes):

```bash
cd example
dart run ../packages/fluau/bin/bootstrap.dart
# or: dart run fluau:bootstrap
```

## Track 2: First plugin

1. Copy `example/assets/plugins/fake_vpn/` to a new folder under `assets/plugins/`.
2. Change `id` / `name` / `version` in `plugin.yaml`. Keep permission shapes as in
   the example manifests and stubs — those files are the source of truth.
3. Register the asset folder in the example `pubspec.yaml` and in
   `PluginRegistryLoader.registerPackages([...])` in `main.dart`.
4. Run the app, select your plugin, grant permissions, and confirm one screen +
   one event round-trip.

For mental model and permissions, see [plugin/OVERVIEW.md](plugin/OVERVIEW.md)
and [plugin/PERMISSIONS.md](plugin/PERMISSIONS.md).

## Track 3: Integrate into your FRB app

Once FRB already works in your project:

1. Add the `fluau` Dart dependency and the Rust core crate.
2. Add `fluau.yaml` and run `dart run fluau:bootstrap`.
3. Bind the stamped adapter after `RustLib.init()`.
4. Implement a [UI catalog](host/UI_CATALOG.md) and a [grant store](host/GRANTS.md).

Details: [host/INTEGRATION.md](host/INTEGRATION.md).

## Next

| Goal | Doc |
|------|-----|
| Architecture / trust | [concepts/ARCHITECTURE.md](concepts/ARCHITECTURE.md) |
| Host APIs | [host/EXTEND_HOST_API.md](host/EXTEND_HOST_API.md) |
| Capabilities | [capabilities/OVERVIEW.md](capabilities/OVERVIEW.md) |
| When to regenerate | [codegen/WHEN_TO_RUN.md](codegen/WHEN_TO_RUN.md) |
