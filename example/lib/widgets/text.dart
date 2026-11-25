import 'package:flutter/material.dart';
import 'package:fluau/fluau.dart';
import 'types.dart';

/// Text widget definition for Lua
///
/// This is a dataclass (not a StatelessWidget) that defines the structure
/// of a Text widget that can be created from Lua.
///
/// Lua usage:
///   ui.Text {
///     text = "Hello from Lua!",
///     size = "large",
///     color = "primary",
///     weight = "bold"
///   }
@LuaWidget(name: 'Text')
class LuaTextWidget implements LuaWidgetInterface {
  /// The text to display (required)
  @LuaProperty(required: true)
  final String text;

  /// Text size preset: "small", "medium", "large"
  @LuaProperty()
  final TextSize? size;

  /// Text color preset: "primary", "secondary", "error", "text"
  @LuaProperty()
  final TextColor? color;

  /// Font weight preset: "normal", "bold"
  @LuaProperty()
  final FontWeightPreset? weight;

  const LuaTextWidget({required this.text, this.size, this.color, this.weight});

  /// Build the Flutter Text widget from this definition
  ///
  /// This method is called by the code-generated serializer to convert
  /// the Lua-defined structure into a Flutter widget.
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: _getFontSize(size),
        color: _getColor(color, context),
        fontWeight: _getFontWeight(weight),
      ),
    );
  }

  /// Get font size from TextSize enum
  double? _getFontSize(TextSize? size) {
    switch (size) {
      case TextSize.small:
        return 14;
      case TextSize.medium:
        return 16;
      case TextSize.large:
        return 24;
      case null:
        return null;
    }
  }

  /// Get color from TextColor enum using the current theme
  Color? _getColor(TextColor? color, BuildContext context) {
    if (color == null) return null;

    switch (color) {
      case TextColor.primary:
        return Theme.of(context).primaryColor;
      case TextColor.secondary:
        return Theme.of(context).colorScheme.secondary;
      case TextColor.error:
        return Theme.of(context).colorScheme.error;
      case TextColor.text:
        return Theme.of(context).textTheme.bodyLarge?.color;
    }
  }

  /// Get FontWeight from FontWeightPreset enum
  FontWeight _getFontWeight(FontWeightPreset? weight) {
    switch (weight) {
      case FontWeightPreset.bold:
        return FontWeight.bold;
      case FontWeightPreset.normal:
      case null:
        return FontWeight.normal;
    }
  }
}
