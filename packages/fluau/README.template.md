# fluau

Sandboxed **Luau** plugins for Flutter. Plugins draw from a **host-owned** UI
catalog, talk to the app through gated host services, and can expose typed
capabilities back to Dart.

Full monorepo docs (example walkthrough, architecture): see the
[repository Getting started](https://github.com/c4rl2s0n/fluau/blob/main/docs/GETTING_STARTED.md).

{{include:docs/GETTING_STARTED.md#prerequisite}}

## Install

```yaml
dependencies:
  fluau: ^0.1.0
```

Also depend on the Rust runtime from the monorepo (`lua_plugin_core`, git/path
until published on crates.io).

{{include:docs/host/INTEGRATION.md#bootstrap-bind}}

Pass your UI catalog into `LuaPlugin` / `LuaPluginView` via `buildWidget` — this
package does **not** ship default widgets. See
[UI catalog](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/UI_CATALOG.md)
and
[plugin permissions](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/PLUGIN_PERMISSIONS.md).

## What this package provides

- `LuaPluginBridge` + `dart run fluau:bootstrap`
- Package YAML loader, permission sheet helpers, `PluginGrantStore`
- Annotations (`@LuaWidget`, `@LuaCapability`, …) and session host widgets
- `LuaWidgetInterface` only — no default catalog

## License

MIT
