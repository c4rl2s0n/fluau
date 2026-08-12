import 'package:flutter/material.dart';
import '../annotations.dart';

/// Text widget definition for Lua
///
/// Lua usage:
///   ui.Text { text = "Hello", size = "large", color = "primary" }
@LuaWidget(name: 'Text')
class LuaTextWidget {
  /// The text to display (required)
  @LuaProperty(required: true)
  final String text;
  
  /// Text size preset: "small", "medium", "large"
  @LuaProperty()
  final String? size;
  
  /// Text color preset: "primary", "secondary", "error", "text"
  @LuaProperty()
  final String? color;
  
  /// Font weight: "normal", "bold"
  @LuaProperty()
  final String? weight;
  
  const LuaTextWidget({
    required this.text,
    this.size,
    this.color,
    this.weight,
  });
  
  /// Build the Flutter Text widget from this definition
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: _getFontSize(size, context),
        color: _getColor(color, context),
        fontWeight: _getFontWeight(weight),
      ),
    );
  }
  
  double? _getFontSize(String? size, BuildContext context) {
    if (size == null) return null;
    switch (size) {
      case 'small': return 14;
      case 'medium': return 16;
      case 'large': return 24;
      default: return null;
    }
  }
  
  Color? _getColor(String? color, BuildContext context) {
    if (color == null) return null;
    switch (color) {
      case 'primary': return Theme.of(context).primaryColor;
      case 'secondary': return Theme.of(context).colorScheme.secondary;
      case 'error': return Theme.of(context).colorScheme.error;
      case 'text': return Theme.of(context).textTheme.bodyLarge?.color;
      default: return null;
    }
  }
  
  FontWeight _getFontWeight(String? weight) {
    if (weight == null) return FontWeight.normal;
    switch (weight) {
      case 'bold': return FontWeight.bold;
      default: return FontWeight.normal;
    }
  }
}
