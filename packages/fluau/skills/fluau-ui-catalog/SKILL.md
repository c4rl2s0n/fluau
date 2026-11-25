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
* Annotate catalog classes with `@LuaWidget` and implement `LuaWidgetInterface`. The **generative constructor parameters** are the Lua API. `@LuaProperty` / `@LuaCallback` / `@LuaChildren` on **ctor params** are optional renames only; required/optional is inferred from nullability and Dart defaults. Field-only annotations are ignored.
* Multiple public generative constructors are all exposed: unnamed → `ui.Text`; named `styled` → `ui.Text_styled`. `Key` / `super.key` is always skipped.
* Serializers are a **standalone** library under `dart.lua_root` (default `lib/fluau/widget_serializers.g.dart`) — import it; there is no `catalog.dart` / `part of` coupling.
* Always pass generated `LuaWidgetRegistry.buildFromMap` into `LuaPlugin` / `LuaPluginView` as `buildWidget`.
* Register Rust UI setup via `SetupOptions.ui_setup: Some(lua_engine::setup_lua_api)`. **Without it, Lua gets an empty `ui` table** and `ui.Text` etc. fail — do not hand-emit JSON as a workaround.
* Only run `flutter_rust_bridge_codegen generate` when FRB-exposed APIs changed — not for every widget tweak.

Docs: [UI catalog](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/UI_CATALOG.md),
[When to regenerate](https://github.com/c4rl2s0n/fluau/blob/main/docs/codegen/WHEN_TO_RUN.md).

## Examples

### Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.3
```

### Generate (default: widgets + capabilities)

From the Flutter app root (`fluau.yaml` optional — paths from yaml or built-in defaults):

```bash
dart run fluau_codegen
```

Selective: `dart run fluau_codegen --widgets` or `--capabilities`. CLI flags override yaml.

Emits: `lib/fluau/widget_serializers.g.dart` (or `dart.lua_root`), `lua_engine.rs` (`setup_lua_api`), `api/lua.rs`, `ui.d.luau`, plus capability `*.g.dart` / `capabilities.d.luau` when present.

### Wire the catalog into LuaPlugin

```dart
import 'package:my_app/fluau/widget_serializers.g.dart';

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
  final String text;   // required (non-nullable, no default)
  final String? color; // optional

  const LuaTextWidget({required this.text, this.color});

  @override
  Widget build(BuildContext context) => Text(text);
}
```
