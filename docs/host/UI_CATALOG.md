# Host-owned UI catalog

fluau does **not** ship default widgets. The host defines the closed vocabulary
plugins may emit. That keeps trust clear and lets each app theme and constrain
controls itself.

## Pieces

1. **Dart definitions** — classes implementing `LuaWidgetInterface`, annotated
   with `@LuaWidget` / `@LuaProperty` / `@LuaCallback` / `@LuaChildren`.
2. **Codegen** — produces Dart serializers + registry, Rust `lua_engine.rs` UI
   builders, and `ui.d.luau` stubs.
3. **Registration** — pass `SetupOptions.ui_setup` in Rust; pass
   `buildWidget: YourRegistry.buildFromMap` into `LuaPlugin` / `LuaPluginView`.

The example catalog lives under `example/lib/widgets/` (`catalog.dart` +
concrete widgets). Copy that layout rather than inventing a new one.

## After adding a widget

Run `./tool/generate.sh` (or the fluau_codegen CLI against your catalog
directory). Only run `flutter_rust_bridge_codegen generate` if FRB-exposed APIs
changed. See [codegen/WHEN_TO_RUN.md](../codegen/WHEN_TO_RUN.md).
