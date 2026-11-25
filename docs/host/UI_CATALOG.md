# Host-owned UI catalog

fluau does **not** ship default widgets. The host defines the closed vocabulary
plugins may emit. That keeps trust clear and lets each app theme and constrain
controls itself.

## Pieces

1. **Dart definitions** — classes implementing `LuaWidgetInterface`, annotated
   with `@LuaWidget` (and optionally `@LuaData`). The **generative constructor
   parameters** are the Lua API — not fields. Annotations on ctor params
   (`@LuaProperty` / `@LuaCallback` / `@LuaChildren`) are **optional renames**
   only; required/optional comes from nullability and Dart defaults.
2. **Codegen** — add `fluau_codegen` as a **dev_dependency**, then run
   `dart run fluau_codegen` from the app root (paths from
   [`fluau.yaml`](FLUAU_YAML.md) or built-in defaults). Emits a **standalone**
   `widget_serializers.g.dart` under `dart.lua_root` (default `lib/fluau/`) —
   no `catalog.dart` / `part of` coupling. Never hand-roll a Dart registry —
   use generated `LuaWidgetRegistry.buildFromMap`.
3. **Registration** — pass `SetupOptions.ui_setup: Some(lua_engine::setup_lua_api)`
   in Rust (via `fluau::setup` at process start); import the serializers and pass
   `buildWidget: LuaWidgetRegistry.buildFromMap` into `LuaPlugin` /
   `LuaPluginView`. Without `ui_setup`, Rust installs an **empty** `ui` table
   and `ui.Text` etc. fail from Lua.

### Constructor → Lua names

| Dart | Lua entry |
|------|-----------|
| Unnamed ctor on `@LuaWidget(name: 'Text')` | `ui.Text { ... }` |
| Named ctor `LuaTextWidget.styled(...)` | `ui.Text_styled { ... }` |

`Key` / `super.key` is always skipped. Multiple public generative constructors
are all exposed; no `@LuaConstructor` required.

### Optional arguments

| Param | Lua / fromJson |
|-------|----------------|
| Non-nullable, no default | **required** |
| Nullable (`T?`) | **optional** — omit / nil → `null` |
| Non-nullable **with default** | **optional** — use Dart default when JSON key absent |

### Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.4
```

```bash
dart run fluau_codegen
```

Emits `lib/fluau/widget_serializers.g.dart` (or `dart.lua_root`),
`lua_engine.rs` (`setup_lua_api`), `api/lua.rs`, and `ui.d.luau` (plus
capability artifacts when present under `codegen.input`).

The example catalog lives under `example/lib/widgets/` with serializers in
`example/lib/fluau/`. Copy that layout rather than inventing a new one.

### Annotate a widget

```dart
@LuaWidget(name: 'Text')
class LuaTextWidget implements LuaWidgetInterface {
  final String text;
  final String? color;

  const LuaTextWidget({required this.text, this.color});

  @override
  Widget build(BuildContext context) => Text(text);
}
```

Import the generated registry:

```dart
import 'package:my_app/fluau/widget_serializers.g.dart';

LuaPlugin(
  pluginId: pluginId,
  grants: grants,
  buildWidget: LuaWidgetRegistry.buildFromMap,
);
```

## After adding a widget

Run `./tool/generate.sh`, or `dart run fluau_codegen` from the app root. Only
run `flutter_rust_bridge_codegen generate` if FRB-exposed APIs changed. See
[codegen/WHEN_TO_RUN.md](../codegen/WHEN_TO_RUN.md).
