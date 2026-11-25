# fluau

Sandboxed Luau plugins for Flutter. The Dart package is **`fluau`**; the example
app and Rust runtime live in this monorepo.

**Requires** a Flutter–Rust bridge such as
[flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/) (example pin
**2.13.0**). Bridge-from-zero is covered by FRB’s docs, not ours.

## Packages

- **`packages/fluau`** — Dart tools: bridge, grants, loader, annotations (`dart run fluau:bootstrap`)
- **`crates/lua_plugin_core`** — Rust runtime (git/path until crates.io under the fluau family)
- **`example/`** — runnable host with demo HostAPIs and a sample UI catalog

## Start here

- [Getting started](docs/GETTING_STARTED.md)
- [Architecture](docs/concepts/ARCHITECTURE.md)
- [Host integration](docs/host/INTEGRATION.md)
- [UI catalog](docs/host/UI_CATALOG.md)
- [Grants](docs/host/GRANTS.md)

## Quick start (example)

```bash
cd example
flutter pub get
flutter run
```

```bash
cd example
dart run ../packages/fluau/bin/bootstrap.dart
```
