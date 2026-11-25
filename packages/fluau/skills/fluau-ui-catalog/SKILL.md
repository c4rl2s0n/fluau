---
name: fluau-ui-catalog
description: >-
  Use when defining or extending the host-owned fluau UI catalog with @LuaWidget
  types, serializers, and LuaPlugin buildWidget wiring.
---

# Host-owned UI catalog

## Guidelines

* fluau does **not** ship default widgets. The app owns the closed vocabulary plugins may emit.
* Add `fluau_codegen` as a **dev_dependency**. Widgets (and capabilities) are generated with the **CLI only** — do **not** use `build_runner` for fluau, and do **not** hand-roll a Dart registry.
* Annotate Flutter `Widget` subclasses (typically `StatelessWidget`) with `@LuaWidget` only. The **generative constructor parameters** are the Lua API. `@LuaProperty` / `@LuaCallback` / `@LuaChildren` on **ctor params** are optional renames only. Field-only annotations are ignored. `Key` / `super.key` is skipped.
* Multiple public generative constructors are all exposed: unnamed → `ui.Text`; named `styled` → `ui.Text_styled`.
* Nested children use `Widget?` / `List<Widget>?` (placed in the tree as-is).
* Serializers are a **standalone** library under `dart.lua_root` (default `lib/fluau/widget_serializers.g.dart`) — import it.
* Always pass generated `LuaWidgetRegistry.buildFromMap` into `LuaPlugin` / `LuaPluginView` as `buildWidget`.
* Register Rust UI setup via `SetupOptions.ui_setup: Some(lua_engine::setup_lua_api)`. **Without it, Lua gets an empty `ui` table**.
* Only run `flutter_rust_bridge_codegen generate` when FRB-exposed APIs changed — not for every widget tweak.

Docs: [UI catalog](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/UI_CATALOG.md),
[When to regenerate](https://github.com/c4rl2s0n/fluau/blob/main/docs/codegen/WHEN_TO_RUN.md).

## Examples

### Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.5
```

### Generate (default: widgets + capabilities)

```bash
dart run fluau_codegen
```

### Wire the catalog into LuaPlugin

```dart
import 'package:my_app/fluau/widget_serializers.g.dart';

LuaPlugin(
  pluginId: pluginId,
  grants: grants,
  buildWidget: LuaWidgetRegistry.buildFromMap,
);
```

### Annotate a widget

```dart
@LuaWidget(name: 'Text')
class LuaTextWidget extends StatelessWidget {
  final String text;
  final String? color;

  const LuaTextWidget({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) => Text(text);
}
```
