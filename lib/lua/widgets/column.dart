import 'package:flutter/material.dart';
import '../annotations.dart';
import '../types.dart';
import 'widget.dart';

/// Column widget definition for Lua
///
/// This is a dataclass (not a StatelessWidget) that defines the structure
/// of a Column widget that can be created from Lua.
///
/// Lua usage:
///   ui.Column {
///     spacing = 16,
///     mainAxisAlignment = "center",
///     crossAxisAlignment = "center",
///     children = {
///       ui.Text { text = "First" },
///       ui.Text { text = "Second" },
///       ui.Button { text = "Click me" }
///     }
///   }
@LuaWidget(name: 'Column', hasChildren: true)
class LuaColumnWidget implements LuaWidgetInterface {
  /// The amount of space between children
  @LuaProperty()
  final double? spacing;
  
  /// How the children should be aligned along the main axis
  @LuaProperty()
  final MainAxisAlignmentPreset? mainAxisAlignment;
  
  /// How the children should be aligned along the cross axis
  @LuaProperty()
  final CrossAxisAlignmentPreset? crossAxisAlignment;
  
  /// The list of child widgets
  @LuaChildren()
  final List<LuaWidgetInterface>? children;
  
  const LuaColumnWidget({
    this.spacing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.children,
  });
  
  /// Build the Flutter Column widget from this definition
  Widget build(BuildContext context) {
    return Column(
      spacing: spacing,
      mainAxisAlignment: _parseMainAxisAlignment(mainAxisAlignment),
      crossAxisAlignment: _parseCrossAxisAlignment(crossAxisAlignment),
      children: children?.map((w) => w.build(context)).toList() ?? [],
    );
  }
  
  /// Parse MainAxisAlignment from MainAxisAlignmentPreset enum
  MainAxisAlignment _parseMainAxisAlignment(MainAxisAlignmentPreset? preset) {
    switch (preset) {
      case MainAxisAlignmentPreset.start:
        return MainAxisAlignment.start;
      case MainAxisAlignmentPreset.center:
        return MainAxisAlignment.center;
      case MainAxisAlignmentPreset.end:
        return MainAxisAlignment.end;
      case MainAxisAlignmentPreset.spaceBetween:
        return MainAxisAlignment.spaceBetween;
      case MainAxisAlignmentPreset.spaceAround:
        return MainAxisAlignment.spaceAround;
      case MainAxisAlignmentPreset.spaceEvenly:
        return MainAxisAlignment.spaceEvenly;
      case null:
        return MainAxisAlignment.start;
    }
  }
  
  /// Parse CrossAxisAlignment from CrossAxisAlignmentPreset enum
  CrossAxisAlignment _parseCrossAxisAlignment(CrossAxisAlignmentPreset? preset) {
    switch (preset) {
      case CrossAxisAlignmentPreset.start:
        return CrossAxisAlignment.start;
      case CrossAxisAlignmentPreset.center:
        return CrossAxisAlignment.center;
      case CrossAxisAlignmentPreset.end:
        return CrossAxisAlignment.end;
      case CrossAxisAlignmentPreset.stretch:
        return CrossAxisAlignment.stretch;
      case CrossAxisAlignmentPreset.baseline:
        return CrossAxisAlignment.baseline;
      case null:
        return CrossAxisAlignment.center;
    }
  }
}
