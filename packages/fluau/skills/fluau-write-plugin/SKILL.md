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
* `render()` **must** return a JSON **string** produced by `ui.*` constructors. Returning a plain Lua table fails with `render() must return a widget (JSON string from ui.*)`.
* Entrypoints: `render()` required for UI sessions; `on_event` / `flush_state` / `init` / `on_host_result` optional; `dispatch(method, args)` required only when the host calls a capability.
* Sessions start with a host-sent `{ type = "bootstrap" }` event — handle or ignore in `on_event`.
* `ui.*` constructors only exist after the host runs `fluau_codegen` and registers the catalog (`register_ui_catalog()` or `SetupOptions.ui_setup`) — see `fluau-ui-catalog` / `fluau-integrate-host`.
* Declare host API needs in `plugin.yaml`. Use the compact schema below; host entries may be a string id or a single-key map (`http: { domains: [...] }`, `optional: true`) — do not invent undocumented keys.
* Prefer the minimal example below (or the monorepo `counter` package) over inventing a new layout.
* Prefer `enums.TextSize.large` (etc.) over raw strings when the host catalog exposes enums; plain strings still work.
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

### Compact `plugin.yaml` schema

```yaml
id: hello                 # required string
name: Hello               # required string
version: 0.0.1            # required string
main: main.lua            # required (or legacy `script`)
capabilities:             # optional string list
  - vpn.provider
permissions:              # optional
  host:                   # string id or single-key map
    - log:
        optional: true
```

Optional package field: `modules:` (`name` + `path`) for multi-file plugins.

### Minimal `plugin.yaml` + `main.lua`

```yaml
id: hello
name: Hello
version: 0.0.1
main: main.lua
```

```lua
function render()
  return ui.Column {
    spacing = 8,
    children = {
      ui.Text { text = "Hello fluau", size = enums.TextSize.large },
      ui.Button { text = "Ping", onPressed = { type = "ping" } },
    },
  }
end

function on_event(event)
  if event.type == "bootstrap" then
    return {}
  end
  if event.type == "ping" then
    return {}
  end
  return {}
end
```

Widget names (`ui.Column`, `ui.Text`, …) must exist in the **host** UI catalog. For capability calls, also implement `dispatch(method, args)` and list the capability under `capabilities:`.

### Register from the Flutter host

```dart
await PluginRegistryLoader.registerPackages(const [
  'assets/plugins/my_plugin',
]);
```

Ensure each plugin folder is listed under `flutter: assets:` in the app `pubspec.yaml`.
