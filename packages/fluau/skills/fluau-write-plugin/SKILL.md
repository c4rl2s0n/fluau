---
name: fluau-write-plugin
description: >-
  Use when authoring or editing a Luau plugin package (plugin.yaml, entry
  script, modules, UI snapshots, events) for a fluau host.
---

# Write a fluau plugin

## Guidelines

* A plugin is a **package**: `plugin.yaml` + entry script + optional `lib/` modules registered with the host from Flutter assets.
* Plugins **render JSON UI snapshots** from the host’s closed widget catalog. Do not invent Flutter widgets from Lua.
* Interaction is **event-driven**: controls carry data payloads; the host delivers events and asks for a new snapshot.
* Declare host API needs in `plugin.yaml`. Treat example manifests and generated `*.d.luau` stubs as schema source of truth — do not invent field inventories in docs or chat.
* Prefer copying structure from the monorepo `fake_vpn` example over inventing a new layout.
* Stay inside the host UI vocabulary; new controls require a host catalog change (`fluau-ui-catalog`), not a plugin-local hack.

Docs: [Plugin overview](https://github.com/c4rl2s0n/fluau/blob/main/docs/plugin/OVERVIEW.md),
[Permissions](https://github.com/c4rl2s0n/fluau/blob/main/docs/plugin/PERMISSIONS.md).

## Examples

### Minimal package layout

```text
assets/plugins/my_plugin/
  plugin.yaml
  main.lua
  lib/   # optional modules
```

### Register from the Flutter host

```dart
await PluginRegistryLoader.registerPackages(const [
  'assets/plugins/my_plugin',
]);
```

Ensure each plugin folder is listed under `flutter: assets:` in the app `pubspec.yaml`.
