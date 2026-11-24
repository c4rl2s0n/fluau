# Luau plugin framework (tools + example)

Sandboxed Luau plugins for Flutter via a **tools-only** Rust rlib and Dart package. The app owns FRB, HostAPIs, and the UI catalog.

## Packages

- **`crates/lua_plugin_core`** — session, sandbox, permission gate, HostApi registry (empty until the app registers surfaces)
- **`packages/lua_plugin`** — `LuaPluginBridge`, grants, YAML package loader, `@LuaWidget` helpers
- **`example/`** — runnable Flutter PoC (demo http/db/crypto/log + Proton/fake VPN plugins)

## Quick start (example)

```bash
cd example
flutter pub get
flutter run
```

Bootstrap stamped FRB/Dart glue (requires FRB already set up):

```bash
cd example
dart run ../packages/lua_plugin/bin/bootstrap.dart
```

See [docs/PACKAGING.md](docs/PACKAGING.md) for HostApi/UI extension and FRB version pinning, and [docs/CAPABILITIES.md](docs/CAPABILITIES.md) for typed capability contracts (`@LuaCapability`).
