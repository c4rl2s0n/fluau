/// Type definitions for Lua plugin framework
///
/// Host-owned enums used as `@LuaWidget` properties. Codegen emits Luau string
/// unions and an `enums.<Name>` value table so plugins can write
/// `size = enums.TextSize.large` (wire value is still the string `"large"`).
///
/// Flutter SDK enums cannot be annotated — wrap them in presets like
/// [MainAxisAlignmentPreset] / [CrossAxisAlignmentPreset].

library;

import 'package:fluau/fluau.dart';

/// Text size presets for controlling font size
///
/// Lua: `size = enums.TextSize.large` or `size = "large"`
@LuaEnum()
enum TextSize {
  /// Small text size (14px)
  small,

  /// Medium text size (16px) - default body text
  medium,

  /// Large text size (24px) - for headings
  large,
}

/// Text color presets for controlling text color
///
/// Lua: `color = enums.TextColor.primary` or `color = "primary"`
@LuaEnum()
enum TextColor {
  /// Primary color from the app's theme
  primary,

  /// Secondary color from the app's theme
  secondary,

  /// Error color from the app's theme
  error,

  /// Default text color from the app's theme
  text,
}

/// Font weight presets for controlling text weight
///
/// Lua: `weight = enums.FontWeightPreset.bold` or `weight = "bold"`
@LuaEnum()
enum FontWeightPreset {
  /// Normal font weight
  normal,

  /// Bold font weight
  bold,
}

/// Main axis alignment for Row and Column widgets
///
/// Lua: `mainAxisAlignment = enums.MainAxisAlignmentPreset.center`
@LuaEnum()
enum MainAxisAlignmentPreset {
  /// Align items to the start of the main axis
  start,

  /// Center items along the main axis
  center,

  /// Align items to the end of the main axis
  end,

  /// Distribute items evenly with equal space between them
  spaceBetween,

  /// Distribute items evenly with equal space around them
  spaceAround,

  /// Distribute items evenly with equal space between and around them
  spaceEvenly,
}

/// Cross axis alignment for Row and Column widgets
///
/// Lua: `crossAxisAlignment = enums.CrossAxisAlignmentPreset.stretch`
@LuaEnum()
enum CrossAxisAlignmentPreset {
  /// Align items to the start of the cross axis
  start,

  /// Center items along the cross axis
  center,

  /// Align items to the end of the cross axis
  end,

  /// Stretch items to fill the cross axis
  stretch,

  /// Align items along their baseline
  baseline,
}
