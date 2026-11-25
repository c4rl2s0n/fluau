---
name: fluau-plugin-permissions
description: >-
  Use when implementing PluginGrantStore, showing the grant sheet, or explaining
  request vs user permission decisions for fluau plugins.
---

# Plugin permissions (host)

## Guidelines

* The **manifest** is the plugin’s request; the **user decision** is what the host persists and passes into session start.
* Required host APIs must be granted to start; optional APIs may be denied — plugins should feature-detect (`if host.log then … end`).
* Always implement or inject a `PluginGrantStore` (`read` / `write` / `clear`). Do not hard-code persistence inside the session host.
* `MemoryPluginGrantStore` is for tests/demos only (ephemeral). Prefer `JsonFilePluginGrantStore` as a starting point or a custom secure store.
* Use `StoredPluginGrants.covers(manifest)` to skip re-prompting when version, required APIs, and constraint fingerprints still match.
* Use `showPluginGrantSheet` for a standard review UI, or build your own prompt that writes into the store.

Docs: [Plugin permissions](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/PLUGIN_PERMISSIONS.md).

## Examples

### Ephemeral vs file store

```dart
final grantStore = MemoryPluginGrantStore(); // demos / tests

final grantStore = JsonFilePluginGrantStore(
  '${Directory.systemTemp.path}/my_app_plugin_grants.json',
);
```

### Resolve grants before starting a plugin

```dart
final previous = await grantStore.read(manifest.id);
if (previous != null && previous.covers(manifest)) {
  activeGrants = previous.toDto();
} else {
  final decided = await showPluginGrantSheet(
    context: context,
    manifest: manifest,
    previous: previous,
  );
  if (decided != null) {
    await grantStore.write(decided);
    activeGrants = decided.toDto();
  }
}
```
