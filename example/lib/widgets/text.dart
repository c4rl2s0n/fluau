import 'package:flutter/material.dart';
import 'package:fluau/fluau.dart';
import 'types.dart';

/// Text widget for Lua.
///
/// Lua usage:
///   ui.Text {
///     text = "Hello from Lua!",
///     size = "large",
///     color = "primary",
///     weight = "bold"
///   }
@LuaWidget(name: 'Text')
class LuaTextWidget extends StatelessWidget {
  final String text;
  final TextSize? size;
  final TextColor? color;
  final FontWeightPreset? weight;

  const LuaTextWidget({
    super.key,
    required this.text,
    this.size,
    this.color,
    this.weight,
  });

  @override
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
