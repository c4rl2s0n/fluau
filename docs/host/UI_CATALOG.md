# Host-owned UI catalog

fluau does **not** ship default widgets. The host defines the closed vocabulary
plugins may emit. That keeps trust clear and lets each app theme and constrain
controls itself.

## Pieces

1. **Dart definitions** — Flutter `Widget` subclasses (typically
   `StatelessWidget`) annotated with `@LuaWidget`. The **generative constructor
   parameters** are the Lua API. `Key` / `super.key` is skipped. Optional
   `@LuaProperty` / `@LuaCallback` / `@LuaChildren` on ctor params are renames
   only; required/optional comes from nullability and Dart defaults.
2. **Codegen** — add `fluau_codegen` as a **dev_dependency**, then run
   `dart run fluau_codegen` from the app root (paths from
   [`fluau.yaml`](FLUAU_YAML.md) or built-in defaults). Emits a **standalone**
   `widget_serializers.g.dart` under `dart.lua_root` (default `lib/fluau/`).
   Never hand-roll a Dart registry — use generated
   `LuaWidgetRegistry.buildFromMap`.
3. **Registration** — pass `SetupOptions.ui_setup: Some(lua_engine::setup_lua_api)`
   in Rust; import the serializers and pass
   `buildWidget: LuaWidgetRegistry.buildFromMap` into `LuaPlugin` /
   `LuaPluginView`. Without `ui_setup`, Rust installs an **empty** `ui` table.

### Constructor → Lua names

| Dart | Lua entry |
|------|-----------|
| Unnamed ctor on `@LuaWidget(name: 'Text')` | `ui.Text { ... }` |
| Named ctor `LuaTextWidget.styled(...)` | `ui.Text_styled { ... }` |

### Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.5
```

```bash
dart run fluau_codegen
```

Emits `lib/fluau/widget_serializers.g.dart` (or `dart.lua_root`),
`lua_engine.rs` (`setup_lua_api`), `api/lua.rs`, and `ui.d.luau`.

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
