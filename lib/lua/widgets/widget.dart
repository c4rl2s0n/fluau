import 'package:flutter/material.dart';

/// Abstract base class for all Lua widget builders
///
/// Each widget type (Text, Button, Column, etc.) should have its own implementation
/// of this class that knows how to convert Lua properties to Flutter widgets.
///
/// Example:
/// ```dart
/// class TextLuaWidgetBuilder implements LuaWidgetBuilder {
///   @override
///   String get type => 'Text';
///   
///   @override
///   Widget build(BuildContext context, Map<String, dynamic> properties) {
///     final text = properties['text'] as String? ?? '';
///     final style = properties['style'] as Map<String, dynamic>?;
///     return Text(text, style: _buildTextStyle(style));
///   }
/// }
/// ```
abstract class LuaWidgetBuilder {
  /// The widget type identifier (e.g., 'Text', 'Button', 'Column')
  String get type;

  /// Build a Flutter widget from the given properties
  Widget build(BuildContext context, Map<String, dynamic> properties);

  /// Static factory method to create the appropriate builder for a widget type
  /// All widget builders must be registered here
  static LuaWidgetBuilder? create(String type) {
    switch (type) {
      case 'Text':
        return TextLuaWidgetBuilder();
      // Future widget types can be added here
      // case 'Button':
      //   return ButtonLuaWidgetBuilder();
      // case 'Column':
      //   return ColumnLuaWidgetBuilder();
      default:
        return null; // Unknown widget type
    }
  }

  /// Static method to build a widget from a map, handling the type dispatch
  static Widget build(BuildContext context, Map<String, dynamic> widgetMap) {
    final widgetType = widgetMap['type'] as String?;

    if (widgetType == null) {
      return const SizedBox(); // Empty widget
    }

    final builder = create(widgetType);
    if (builder == null) {
      return Text(
        'Unknown widget type: $widgetType',
        style: const TextStyle(color: Colors.red),
      );
    }

    // Remove 'type' from properties before passing to builder
    final properties = Map<String, dynamic>.from(widgetMap);
    properties.remove('type');

    return builder.build(context, properties);
  }
}

/// Builder for Text widgets
///
/// Converts Lua Text widget properties to Flutter Text widget.
///
/// Lua properties:
/// - `text` (required): The text to display
/// - `style` (optional): A map of style properties:
///   - `fontSize`: Font size as double
///   - `color`: Color as hex string (e.g., "#FF0000FF")
///   - `fontWeight`: Font weight as string (e.g., "bold", "normal")
///   - `fontStyle`: Font style as string (e.g., "italic", "normal")
class TextLuaWidgetBuilder implements LuaWidgetBuilder {
  @override
  String get type => 'Text';

  @override
  Widget build(BuildContext context, Map<String, dynamic> properties) {
    final text = properties['text'] as String? ?? '';
    final styleMap = properties['style'] as Map<String, dynamic>?;
    final style = _buildTextStyle(styleMap);

    return Text(text, style: style);
  }

  /// Build a TextStyle from Lua style properties
  TextStyle _buildTextStyle(Map<String, dynamic>? styleMap) {
    if (styleMap == null) {
      return const TextStyle();
    }

    return TextStyle(
      fontSize: styleMap['fontSize'] as double?,
      color: _parseColor(styleMap['color'] as String?),
      fontWeight: _parseFontWeight(styleMap['fontWeight'] as String?),
      fontStyle: _parseFontStyle(styleMap['fontStyle'] as String?),
    );
  }

  /// Parse a color from a hex string (e.g., "#FF0000FF")
  Color? _parseColor(String? hex) {
    if (hex == null) return null;
    
    // Remove the # prefix if present
    final cleanHex = hex.replaceFirst('#', '');
    
    // Try to parse as ARGB (8 hex digits) or RGB (6 hex digits)
    try {
      if (cleanHex.length == 8) {
        // ARGB format
        return Color(int.parse('0x$cleanHex'));
      } else if (cleanHex.length == 6) {
        // RGB format - add FF (fully opaque) as alpha
        return Color(int.parse('0xFF$cleanHex'));
      }
    } catch (e) {
      // Invalid color format, return null to use default
      return null;
    }
    
    return null; // Invalid format
  }

  /// Parse font weight from string
  FontWeight _parseFontWeight(String? weight) {
    if (weight == null) return FontWeight.normal;
    
    switch (weight.toLowerCase()) {
      case 'bold':
      case 'w700':
        return FontWeight.bold;
      case 'w600':
        return FontWeight.w600;
      case 'w500':
        return FontWeight.w500;
      case 'w400':
      case 'normal':
        return FontWeight.normal;
      case 'w300':
        return FontWeight.w300;
      case 'w200':
        return FontWeight.w200;
      case 'w100':
        return FontWeight.w100;
      default:
        return FontWeight.normal;
    }
  }

  /// Parse font style from string
  FontStyle _parseFontStyle(String? style) {
    if (style == null) return FontStyle.normal;
    
    switch (style.toLowerCase()) {
      case 'italic':
        return FontStyle.italic;
      case 'normal':
      default:
        return FontStyle.normal;
    }
  }
}
