# Host-owned UI catalog

fluau does **not** ship default widgets. The host defines the closed vocabulary
plugins may emit. That keeps trust clear and lets each app theme and constrain
controls itself.

## Pieces

1. **Dart definitions** — classes implementing `LuaWidgetInterface`, annotated
   with `@LuaWidget` / `@LuaProperty` / `@LuaCallback` / `@LuaChildren`.
2. **Catalog barrel** — a hand-written `catalog.dart` that imports every widget
   module and declares `part 'widget_serializers.g.dart';`. Codegen hardcodes
   `part of 'catalog.dart';`, so a lone widget file without that barrel will not
   compile against the generated part.
3. **Codegen** — add `fluau_codegen` as a **dev_dependency**, then run
   `dart run fluau_codegen` from the app root (paths from
   [`fluau.yaml`](FLUAU_YAML.md) or built-in defaults). Never hand-roll a Dart
   registry — use generated `LuaWidgetRegistry.buildFromMap`.
4. **Registration** — pass `SetupOptions.ui_setup: Some(lua_engine::setup_lua_api)`
   in Rust (via `fluau::setup` at process start); pass
   `buildWidget: YourRegistry.buildFromMap` into `LuaPlugin` / `LuaPluginView`.
   Without `ui_setup`, Rust installs an **empty** `ui` table and `ui.Text` etc.
   fail from Lua.

### Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.2
```

```bash
dart run fluau_codegen
```

Emits `widget_serializers.g.dart`, `lua_engine.rs` (`setup_lua_api`), `api/lua.rs`,
and `ui.d.luau` (plus capability artifacts when present under `codegen.input`).

The example catalog lives under `example/lib/widgets/` (`catalog.dart` +
concrete widgets). Copy that layout rather than inventing a new one.

## After adding a widget

Run `./tool/generate.sh`, or `dart run fluau_codegen` from the app root. Only
run `flutter_rust_bridge_codegen generate` if FRB-exposed APIs changed. See
[codegen/WHEN_TO_RUN.md](../codegen/WHEN_TO_RUN.md).
