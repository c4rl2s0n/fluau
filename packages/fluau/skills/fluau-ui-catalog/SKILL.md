---
name: fluau-ui-catalog
description: >-
  Use when defining or extending the host-owned fluau UI catalog with @LuaWidget
  types, serializers, and LuaPlugin buildWidget wiring.
---

# Host-owned UI catalog

## Guidelines

* fluau does **not** ship default widgets. The app owns the closed vocabulary plugins may emit.
* Annotate catalog classes with `@LuaWidget` / `@LuaProperty` / `@LuaCallback` / `@LuaChildren` and implement `LuaWidgetInterface`.
* Keep a hand-written `catalog.dart` that imports every widget module and has `part 'widget_serializers.g.dart';`. Codegen hardcodes `part of 'catalog.dart';` — a lone widget file without that barrel will not compile against the generated part.
* Always pass the generated registry entry point into `LuaPlugin` / `LuaPluginView` as `buildWidget`.
* After adding or changing widgets, regenerate with [`fluau_codegen`](https://pub.dev/packages/fluau_codegen) `--generate` (flags below).
* Only run `flutter_rust_bridge_codegen generate` when FRB-exposed APIs changed — not for every widget tweak.
* Register Rust UI setup via `SetupOptions.ui_setup: Some(lua_engine::setup_lua_api)` in the host crate (call `fluau::setup` from Rust at process start — see `fluau-integrate-host`).

Docs: [UI catalog](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/UI_CATALOG.md),
[When to regenerate](https://github.com/c4rl2s0n/fluau/blob/main/docs/codegen/WHEN_TO_RUN.md).

## Examples

### Codegen flags and outputs

```bash
dart run fluau_codegen --generate \
  --input lib/widgets \
  --rust-out rust/src \
  --dart-out lib/widgets \
  --luau-out assets/plugins/_types
```

| Flag | Required | Meaning |
|------|----------|---------|
| `--input` | yes | Dart catalog directory (annotated widgets) |
| `--rust-out` | yes | Rust `src` directory |
| `--dart-out` | yes | Same widgets directory (serializers land next to catalog) |
| `--luau-out` | no | Defaults to `../../assets/plugins/_types` if omitted |

Emits:

* `widget_serializers.g.dart` — `part of 'catalog.dart';` (Dart registry / `buildFromMap`)
* `lua_engine.rs` — includes `setup_lua_api` for `SetupOptions.ui_setup`
* `api/lua.rs` — legacy FRB helpers + empty `init_lua`
* `ui.d.luau` — Luau widget constructor stubs

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
  buildWidget: LuaWidgetRegistry.buildFromMap, // host-generated
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
