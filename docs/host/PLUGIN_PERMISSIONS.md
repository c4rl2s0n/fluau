# Plugin permissions (host persistence)

The **manifest** is the plugin’s request. The **user decision** is what the host
persists and passes into session start. Required host APIs must be allowed to
run; optional APIs may be denied.

`PluginGrantStore` is the swappable persistence API for those decisions:

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

Implement `PluginGrantStore` and inject it wherever your shell resolves
permissions before starting `LuaPlugin` (see `example/lib/main.dart`). Typical
production choices: secure storage, per-user database, or synced preferences.

`StoredPluginGrants.covers(manifest)` checks version, required APIs, and
constraint fingerprints so a prompt can be skipped when nothing material changed.

For how plugins *declare* permissions, see
[plugin/PERMISSIONS.md](../plugin/PERMISSIONS.md).
