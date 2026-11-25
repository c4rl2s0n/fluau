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
3. **Codegen** — `fluau_codegen --generate` with `--input`, `--rust-out`,
   `--dart-out`, and optional `--luau-out`. Emits `widget_serializers.g.dart`
   (Dart registry), `lua_engine.rs` (`setup_lua_api`), `api/lua.rs`, and
   `ui.d.luau`.
4. **Registration** — pass `SetupOptions.ui_setup: Some(lua_engine::setup_lua_api)`
   in Rust (via `fluau::setup` at process start); pass
   `buildWidget: YourRegistry.buildFromMap` into `LuaPlugin` / `LuaPluginView`.

The example catalog lives under `example/lib/widgets/` (`catalog.dart` +
concrete widgets). Copy that layout rather than inventing a new one.

## After adding a widget

Run `./tool/generate.sh`, or:

```bash
dart run fluau_codegen --generate \
  --input lib/widgets \
  --rust-out rust/src \
  --dart-out lib/widgets \
  --luau-out assets/plugins/_types
```

Only run `flutter_rust_bridge_codegen generate` if FRB-exposed APIs changed.
See [codegen/WHEN_TO_RUN.md](../codegen/WHEN_TO_RUN.md).
