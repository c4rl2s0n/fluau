# Grant storage

`PluginGrantStore` is the swappable persistence API for permission decisions:

- `read(pluginId)`
- `write(grants)`
- `clear(pluginId)`

## Shipped helpers

| Implementation | Use |
|----------------|-----|
| `MemoryPluginGrantStore` | Tests and ephemeral demos (lost on process exit) |
| `JsonFilePluginGrantStore` | Simple file map; inject a path from the app |

The example uses `JsonFilePluginGrantStore` under the system temp directory.

## Custom store

Implement `PluginGrantStore` and inject it wherever your shell resolves grants
before starting `LuaPlugin` (see `example/lib/main.dart`). Typical production
choices: secure storage, per-user database, or synced preferences.

`StoredPluginGrants.covers(manifest)` checks version, required APIs, and
constraint fingerprints so a prompt can be skipped when nothing material changed.
