/// Annotations for Lua plugin code generation
///
/// These annotations are used by the code generator to:
/// - Identify which classes should be exposed to Lua
/// - Extract constructor-parameter information for serialization
/// - Generate Rust UI builders and Luau stubs
library;

/// Marks a Flutter [Widget] as exposable to Lua.
///
/// The annotated class must extend [Widget] (typically [StatelessWidget]).
/// The code generator exposes each public generative constructor: the
/// **constructor parameters** are the Lua snapshot API. Unnamed → `ui.<name>`;
/// named ctor `styled` → `ui.<name>_styled`. `Key` / `super.key` is skipped.
///
/// Example:
/// ```dart
/// @LuaWidget(name: 'Text')
/// class LuaTextWidget extends StatelessWidget {
///   final String text;
///   final String? color;
///
///   const LuaTextWidget({super.key, required this.text, this.color});
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

/// Marks a host-owned Dart enum for the Lua catalog.
///
/// Enums used as `@LuaWidget` / `@LuaData` constructor parameters are always
/// discovered (Luau string union + `enums.<Name>` value table). Use [LuaEnum]
/// to rename the Lua type/table, or to emit an enum that is not yet referenced
/// by a widget param.
///
/// Wire values remain the Dart enum constant names (strings). Plugins may write
/// `size = enums.TextSize.large` or `size = "large"`.
///
/// Flutter / third-party enums cannot be annotated — wrap them in a host-owned
/// preset enum instead.
///
/// Example:
/// ```dart
/// @LuaEnum(name: 'TextSize')
/// enum TextSize { small, medium, large }
/// ```
class LuaEnum {
  /// Lua type and `enums.<name>` table key (defaults to the Dart enum name).
  final String? name;

  const LuaEnum({this.name});
}

/// Marks a class as a Lua-exposable data class (not a widget).
///
/// Data classes are used for nested properties like styles, configurations, etc.
/// They don't have a build method and can't be instantiated directly from Lua
/// as top-level widgets. Same constructor-param rules as [LuaWidget].
///
/// Example:
/// ```dart
/// @LuaData(name: 'TextStyle')
/// class LuaTextStyle {
///   final String? color;
///
///   const LuaTextStyle({this.color});
///
///   TextStyle? toTextStyle() => ...;
/// }
/// ```
class LuaData {
  /// The name to use in Lua (defaults to class name)
  final String? name;

  const LuaData({this.name});
}

/// Optional rename / kind hint on a **constructor parameter**.
///
/// Discovery does not require this annotation — every public generative ctor
/// param is exposed unless it is a Flutter [Key]. Use [LuaProperty] only to
/// override the Lua JSON key name when it should differ from the Dart param.
///
/// Required/optional is inferred: non-nullable with no default → required;
/// nullable or with a Dart default → optional.
///
/// Example:
/// ```dart
/// const LuaTextWidget({
///   required this.text,
///   @LuaProperty(name: 'colour') this.color,
/// });
/// ```
class LuaProperty {
  /// The name to use in Lua (defaults to parameter name)
  final String? name;

  /// Deprecated for inference — nullability/defaults control requiredness.
  /// Kept for source compatibility; ignored by constructor-based codegen.
  final bool required;

  /// Default value as a Lua expression (e.g., '"hello"', '42', 'true')
  /// Only used for optional properties
  final String? defaultValue;

  const LuaProperty({this.name, this.required = false, this.defaultValue});
}

/// Optional rename for a child-list constructor parameter.
///
/// Usually unnecessary: `List<Widget>` params are inferred as children.
/// Use to override the Lua key name.
///
/// Example:
/// ```dart
/// const LuaColumnWidget({
///   @LuaChildren() this.children,
/// });
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
  /// The name to use in Lua (defaults to parameter name)
  final String? name;

  const LuaChildren({this.name});
}

/// Optional rename for an event-payload constructor parameter.
///
/// Usually unnecessary: `LuaEventPayload` (or `Map<String, dynamic>`) params
/// are inferred as callbacks. Prefer `LuaEventPayload?`. Dart `Function` /
/// `VoidCallback` params fail codegen loudly (live closures cannot cross the
/// Lua↔Flutter bridge).
///
/// Lua may pass a table (e.g. `{ type = "login" }`) **or** a function; the
/// runtime turns functions into reserved `{ type = "action", id }` payloads.
/// Flutter dispatches via `PluginEventScope.dispatch` or
/// `PluginEventScope.luaEventHandler`.
///
/// Example:
/// ```dart
/// const LuaButtonWidget({
///   @LuaCallback() this.onPressed,
/// });
/// ```
///
/// Lua usage:
/// ```lua
/// ui.Button {
///   text = "Login",
///   onPressed = function() end, -- or { type = "login" }
/// }
/// ```
class LuaCallback {
  /// The name to use in Lua (defaults to parameter name)
  final String? name;

  const LuaCallback({this.name});
}

/// Marks an abstract class as a typed capability contract (app → plugin `dispatch`).
///
/// Codegen emits a concrete client that calls [LuaPluginBridge.callPlugin] and
/// decodes JSON into DTO types. Lua `dispatch` bodies stay hand-written; stubs
/// are generated for LSP only.
///
/// Example:
/// ```dart
/// @LuaCapability('vpn.provider')
/// abstract class VpnProvider {
///   factory VpnProvider(String pluginId) = _VpnProviderImpl;
///   Future<VpnStatus> getStatus([VpnStatusArgs args]);
/// }
/// ```
class LuaCapability {
  /// Capability id advertised in `plugin.yaml` (e.g. `vpn.provider`).
  final String id;

  const LuaCapability(this.id);
}

/// Optional override for the Lua / `callPlugin` method name.
///
/// Default: Dart `getStatus` → `get_status`.
class LuaCapabilityMethod {
  final String name;

  const LuaCapabilityMethod(this.name);
}

/// Marks a class as a capability DTO (args or result).
///
/// Declare fields and a generative constructor only. Codegen emits top-level
/// `_$TypeFromJson` / `_$TypeToJson` in the part file (used by the generated
/// client) plus Luau table stubs. Do not hand-write serde on the class.
class LuaCapabilityDto {
  /// Optional Luau type name (defaults to the Dart class name).
  final String? name;

  const LuaCapabilityDto({this.name});
}
