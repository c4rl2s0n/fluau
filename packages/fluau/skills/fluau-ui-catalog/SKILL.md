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
* Annotate catalog classes with `@LuaWidget` / `@LuaProperty` / `@LuaCallback` / `@LuaChildren` and implement `LuaWidgetInterface`.
* Keep a hand-written `catalog.dart` that imports every widget module and has `part 'widget_serializers.g.dart';`. Codegen hardcodes `part of 'catalog.dart';`.
* Always pass generated `LuaWidgetRegistry.buildFromMap` into `LuaPlugin` / `LuaPluginView` as `buildWidget`.
* Register Rust UI setup via `SetupOptions.ui_setup: Some(lua_engine::setup_lua_api)`. **Without it, Lua gets an empty `ui` table** and `ui.Text` etc. fail — do not hand-emit JSON as a workaround.
* Only run `flutter_rust_bridge_codegen generate` when FRB-exposed APIs changed — not for every widget tweak.

Docs: [UI catalog](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/UI_CATALOG.md),
[When to regenerate](https://github.com/c4rl2s0n/fluau/blob/main/docs/codegen/WHEN_TO_RUN.md).

## Examples

### Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.2
```

### Generate (default: widgets + capabilities)

From the Flutter app root (`fluau.yaml` optional — paths from yaml or built-in defaults):

```bash
dart run fluau_codegen
```

Selective: `dart run fluau_codegen --widgets` or `--capabilities`. CLI flags override yaml.

Emits: `widget_serializers.g.dart`, `lua_engine.rs` (`setup_lua_api`), `api/lua.rs`, `ui.d.luau`, plus capability `*.g.dart` / `capabilities.d.luau` when present.

### `catalog.dart` barrel

```dart
import 'package:flutter/material.dart';
import 'package:fluau/fluau.dart';

import 'button.dart';
import 'column.dart';
import 'text.dart';
// ... every @LuaWidget module

part 'widget_serializers.g.dart';
```

### Wire the catalog into LuaPlugin

```dart
LuaPlugin(
  pluginId: pluginId,
  grants: grants,
  buildWidget: LuaWidgetRegistry.buildFromMap, // host-generated — never hand-roll
);
```

### Annotate a widget (host package)

```dart
@LuaWidget(name: 'Text')
class LuaTextWidget implements LuaWidgetInterface {
  @LuaProperty(required: true)
  final String text;

  const LuaTextWidget({required this.text});

  @override
  Widget build(BuildContext context) => Text(text);
}
```
