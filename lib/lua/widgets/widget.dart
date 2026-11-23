import 'package:flutter/material.dart';
import '../types.dart';
import 'text.dart';
import 'button.dart';
import 'column.dart';
import 'text_field.dart';
import 'expander.dart';
import 'switch_widget.dart';
import 'select.dart';

// The code-generated serializers will be in a part file
part 'widget_serializers.g.dart';

/// Base interface for all Lua widgets
///
/// Widgets that can be created from Lua must implement this interface.
/// The code generator will create serializers that convert JSON maps
/// to widget instances, which are then built using this method.
///
/// Note: This was renamed from LuaWidget to LuaWidgetInterface to avoid
/// naming conflicts with the @LuaWidget annotation.
abstract interface class LuaWidgetInterface {
  /// Build the Flutter widget from this definition
  Widget build(BuildContext context);
}

/// Empty widget returned for unknown widget types or error cases
class LuaEmptyWidget implements LuaWidgetInterface {
  const LuaEmptyWidget();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
