# Example app

Single Flutter app + one Rust `cdylib` (`RustLib`). Demo HostAPIs and widgets live here; core ships none.

## DX surface

**Rust** (`src/demo_host/mod.rs`):

```rust
demo_host::ensure_runtime(); // once — registers http/db/crypto/log + UI catalog
```

**Flutter** (`lib/main.dart`):

```dart
await RustLib.init();
LuaPluginBridge.bind(FrbLuaPluginBridge());
await PluginRegistryLoader.registerPackages([...]);
LuaPlugin(pluginId: '...');
```

Config: [`lua_plugin.yaml`](lua_plugin.yaml). Packaging docs: [`../docs/PACKAGING.md`](../docs/PACKAGING.md).
