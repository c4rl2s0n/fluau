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
  fluau: ^0.1.7
```

Also depend on the Rust crate [`fluau`](https://crates.io/crates/fluau)
(default features for runtime; `stub-gen` in `build-dependencies`). Use
[`fluau_codegen`](https://pub.dev/packages/fluau_codegen) to regenerate UI/capability
bindings.

### Agent skills

After depending on `fluau`, install the packaged Agent Skills into your app:

```bash
dart run skills@ get
```

Use `--all` to pull skills from every dependency that ships them. Skills land under
`.agents/skills/` (for example `fluau-getting-started`, `fluau-integrate-host`).

{{include:docs/host/INTEGRATION.md#bootstrap-bind}}

Pass your UI catalog into `LuaPlugin` / `LuaPluginView` via `buildWidget` — this
package does **not** ship default widgets. See
[fluau.yaml](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/FLUAU_YAML.md),
[UI catalog](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/UI_CATALOG.md),
and
[plugin permissions](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/PLUGIN_PERMISSIONS.md).

## What this package provides

- `LuaPluginBridge` + `dart run fluau:bootstrap`
- Package YAML loader, permission sheet helpers, `PluginGrantStore`
- Annotations (`@LuaWidget`, `@LuaCapability`, …) and session host widgets
- `LuaWidgetInterface` only — no default catalog

## License

MIT
