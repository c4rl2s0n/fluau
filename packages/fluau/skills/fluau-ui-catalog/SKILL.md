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
* Always pass the generated registry entry point into `LuaPlugin` / `LuaPluginView` as `buildWidget`.
* After adding or changing widgets, regenerate with [`fluau_codegen`](https://pub.dev/packages/fluau_codegen) (Dart serializers + Rust UI builders + `ui.d.luau`).
* Only run `flutter_rust_bridge_codegen generate` when FRB-exposed APIs changed — not for every widget tweak.
* Register Rust UI setup via `SetupOptions.ui_setup` in the host crate.

Docs: [UI catalog](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/UI_CATALOG.md),
[When to regenerate](https://github.com/c4rl2s0n/fluau/blob/main/docs/codegen/WHEN_TO_RUN.md).

## Examples

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
