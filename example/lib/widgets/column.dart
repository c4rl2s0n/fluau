import 'package:flutter/material.dart';
import 'package:fluau/fluau.dart';
import 'types.dart';

/// Column widget for Lua.
///
/// Lua usage:
///   ui.Column {
///     spacing = 16,
///     mainAxisAlignment = enums.MainAxisAlignmentPreset.center,
///     crossAxisAlignment = enums.CrossAxisAlignmentPreset.center,
///     children = {
///       ui.Text { text = "First" },
///       ui.Text { text = "Second" },
///       ui.Button { text = "Click me" }
///     }
///   }
@LuaWidget(name: 'Column', hasChildren: true)
class LuaColumnWidget extends StatelessWidget {
  final double? spacing;
  final MainAxisAlignmentPreset? mainAxisAlignment;
  final CrossAxisAlignmentPreset? crossAxisAlignment;
  final List<Widget>? children;

  const LuaColumnWidget({
    super.key,
    this.spacing,
    this.mainAxisAlignment,
    this.crossAxisAlignment,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: spacing ?? 0,
      mainAxisAlignment: _parseMainAxisAlignment(mainAxisAlignment),
      crossAxisAlignment: _parseCrossAxisAlignment(crossAxisAlignment),
      children: children ?? const [],
    );
  }

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

  CrossAxisAlignment _parseCrossAxisAlignment(
    CrossAxisAlignmentPreset? preset,
  ) {
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
