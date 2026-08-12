import 'package:flutter/material.dart';

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

/// Registry for deserializing Lua widgets from JSON
///
/// This class uses code-generated serializers to convert JSON maps
/// to widget instances, then calls their build() methods.
class LuaWidgetRegistry {
  /// Map of widget type names to their deserialization functions
  static final Map<String, LuaWidgetInterface Function(Map<String, dynamic>)> _builders = {};
  
  /// Register a widget builder for a type
  static void register(String type, LuaWidgetInterface Function(Map<String, dynamic>) builder) {
    _builders[type] = builder;
  }
  
  /// Build a widget from a JSON map
  ///
  /// # Arguments
  /// * `type` - The widget type name (e.g., 'Text', 'Button')
  /// * `json` - The JSON map containing widget properties
  /// * `context` - The Flutter build context
  ///
  /// # Returns
  /// The built Flutter widget, or an empty widget if the type is unknown
  static Widget build(String type, Map<String, dynamic> json, BuildContext context) {
    final builder = _builders[type];
    if (builder != null) {
      try {
        final widget = builder(json);
        return widget.build(context);
      } catch (e) {
        return Text(
          'Error building $type: $e',
          style: const TextStyle(color: Colors.red),
        );
      }
    }
    
    // Unknown widget type - return empty widget
    return const LuaEmptyWidget();
  }
  
  /// Build a widget from a full widget map (including type field)
  static Widget buildFromMap(BuildContext context, Map<String, dynamic> widgetMap) {
    final widgetType = widgetMap['type'] as String?;
    
    if (widgetType == null) {
      return const LuaEmptyWidget();
    }
    
    // Remove 'type' from properties before passing to builder
    final properties = Map<String, dynamic>.from(widgetMap);
    properties.remove('type');
    
    return build(widgetType, properties, context);
  }
}

// The code-generated serializers will be in a part file
// This is included after the manual widget definitions
// part 'widget_serializers.g.dart';

