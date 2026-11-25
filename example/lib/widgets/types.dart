/// Type definitions for Lua plugin framework
///
/// This file contains enum types that are used as properties in Lua widgets.
/// These enums provide a limited, type-safe API for Lua scripts to use,
/// instead of allowing arbitrary values.

library;

/// Text size presets for controlling font size
///
/// Lua usage: `size = "small"`, `size = "medium"`, `size = "large"`
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
/// Lua usage: `color = "primary"`, `color = "secondary"`, `color = "error"`, `color = "text"`
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
/// Lua usage: `weight = "normal"`, `weight = "bold"`
enum FontWeightPreset {
  /// Normal font weight
  normal,
  
  /// Bold font weight
  bold,
}

/// Main axis alignment for Row and Column widgets
///
/// Lua usage: `mainAxisAlignment = "start"`, `mainAxisAlignment = "center"`, etc.
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
/// Lua usage: `crossAxisAlignment = "start"`, `crossAxisAlignment = "center"`, etc.
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
