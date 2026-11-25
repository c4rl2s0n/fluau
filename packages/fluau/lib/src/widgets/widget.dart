import 'package:flutter/material.dart';

/// Base interface for host-owned Lua UI catalog entries.
///
/// Apps define concrete widgets annotated with `@LuaWidget`. Codegen produces
/// serializers and a registry; the package does not ship a default catalog.
abstract interface class LuaWidgetInterface {
  /// Build the Flutter widget from this definition.
  Widget build(BuildContext context);
}

/// Empty widget returned for unknown widget types or error cases.
class LuaEmptyWidget implements LuaWidgetInterface {
  const LuaEmptyWidget();

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// Builds a Flutter widget from a Lua UI snapshot map (`type` + properties).
typedef LuaWidgetMapBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> widgetMap,
);
