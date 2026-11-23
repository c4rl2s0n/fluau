/// Annotations for Lua plugin code generation
///
/// These annotations are used by the code generator to:
/// - Identify which classes should be exposed to Lua
/// - Extract property information for serialization
/// - Generate Rust UserData structs and Lua API bindings

/// Marks a class as a Lua-exposable widget.
///
/// Widget classes must implement [LuaWidget] interface (have a build method).
/// The code generator will create:
/// - Rust UserData struct
/// - Lua constructor (ui.WidgetName)
/// - JSON serializer/deserializer
///
/// Example:
/// ```dart
/// @LuaWidget(name: 'Text')
/// class LuaTextWidget implements LuaWidget {
///   @LuaProperty(required: true)
///   final String text;
///   
///   @override
///   Widget build(BuildContext context) => Text(text);
/// }
/// ```
class LuaWidget {
  /// The name to use in Lua (defaults to class name)
  final String? name;
  
  /// Whether this widget can have children
  final bool hasChildren;
  
  const LuaWidget({this.name, this.hasChildren = false});
}

/// Marks a class as a Lua-exposable data class (not a widget).
///
/// Data classes are used for nested properties like styles, configurations, etc.
/// They don't have a build method and can't be instantiated directly from Lua
/// as top-level widgets.
///
/// Example:
/// ```dart
/// @LuaData(name: 'TextStyle')
/// class LuaTextStyle {
///   @LuaProperty()
///   final String? color;
///   
///   TextStyle? toTextStyle() => ...;
/// }
/// ```
class LuaData {
  /// The name to use in Lua (defaults to class name)
  final String? name;
  
  const LuaData({this.name});
}

/// Marks a property as exposable to Lua.
///
/// Only properties with this annotation will be included in the Lua API.
/// Properties without this annotation are ignored by the code generator.
///
/// Example:
/// ```dart
/// @LuaWidget(name: 'Text')
/// class LuaTextWidget implements LuaWidget {
///   @LuaProperty(required: true)
///   final String text;  // Required in Lua
///   
///   @LuaProperty()
///   final String? color;  // Optional in Lua
///   
///   final int _internal;  // NOT exposed to Lua (no annotation)
///   
///   @override
///   Widget build(BuildContext context) => ...;
/// }
/// ```
class LuaProperty {
  /// The name to use in Lua (defaults to field name)
  final String? name;
  
  /// Whether this property is required in Lua
  /// If true, Lua scripts must provide this property
  final bool required;
  
  /// Default value as a Lua expression (e.g., '"hello"', '42', 'true')
  /// Only used for optional properties
  final String? defaultValue;
  
  const LuaProperty({this.name, this.required = false, this.defaultValue});
}

/// Marks a property as containing child widgets.
///
/// This is used for widget containers like Column, Row, etc.
/// The property type should be List<LuaWidget> or similar.
///
/// Example:
/// ```dart
/// @LuaWidget(name: 'Column', hasChildren: true)
/// class LuaColumnWidget implements LuaWidget {
///   @LuaChildren()
///   final List<LuaWidget>? children;
///   
///   @override
///   Widget build(BuildContext context) => Column(
///     children: children?.map((w) => w.build(context)).toList() ?? [],
///   );
/// }
/// ```
///
/// Lua usage:
/// ```lua
/// ui.Column {
///   children = {
///     ui.Text { text = "First" },
///     ui.Text { text = "Second" }
///   }
/// }
/// ```
class LuaChildren {
  /// The name to use in Lua (defaults to field name)
  final String? name;
  
  const LuaChildren({this.name});
}

/// Marks a property as an event payload forwarded to the plugin host.
///
/// The property type should be `Map<String, dynamic>?`.
/// Lua supplies a table (e.g. `{ type = "login" }`) which is embedded in the
/// UI JSON snapshot. Flutter dispatches that map via [PluginEventScope].
///
/// Example:
/// ```dart
/// @LuaCallback()
/// final Map<String, dynamic>? onPressed;
/// ```
///
/// Lua usage:
/// ```lua
/// ui.Button {
///   text = "Login",
///   onPressed = { type = "login" }
/// }
/// ```
class LuaCallback {
  /// The name to use in Lua (defaults to field name)
  final String? name;
  
  const LuaCallback({this.name});
}
