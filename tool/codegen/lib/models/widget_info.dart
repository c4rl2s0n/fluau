/// Data models for the Lua plugin code generator
///
/// These classes represent the information extracted from Dart source files
/// and are used to generate Rust and Dart code.

/// Information about a Lua-exposable class (widget or data class)
class LuaClassInfo {
  /// The Dart class name (e.g., 'LuaTextWidget')
  final String name;
  
  /// The Dart class name as it appears in source (with generics if any)
  final String dartClassName;
  
  /// The Rust struct name to generate (e.g., 'LuaLuaTextWidget' or custom)
  final String rustStructName;
  
  /// The name to use in Lua (e.g., 'Text')
  final String luaName;
  
  /// Whether this is a widget (true) or data class (false)
  final bool isWidget;
  
  /// Whether this widget can have children
  final bool hasChildren;
  
  /// List of properties for this class
  final List<PropertyInfo> properties;
  
  /// The Dart file where this class is defined
  final String sourceFile;
  
  const LuaClassInfo({
    required this.name,
    required this.dartClassName,
    required this.rustStructName,
    required this.luaName,
    required this.isWidget,
    this.hasChildren = false,
    required this.properties,
    required this.sourceFile,
  });
  
  /// Check if this class has any properties
  bool get hasProperties => properties.isNotEmpty;
  
  /// Get all child widget properties
  List<PropertyInfo> get childWidgetProperties => 
    properties.where((p) => p.isChildWidget).toList();
  
  /// Get all child list properties
  List<PropertyInfo> get childListProperties => 
    properties.where((p) => p.isChildList).toList();
  
  /// Get all callback properties
  List<PropertyInfo> get callbackProperties => 
    properties.where((p) => p.isCallback).toList();
  
  /// Get all data class properties
  List<PropertyInfo> get dataClassProperties => 
    properties.where((p) => p.isDataClass).toList();
}

/// Information about a class property
class PropertyInfo {
  /// The property name in Dart (e.g., 'text')
  final String name;
  
  /// The Dart type as string (e.g., 'String', 'int?', 'LuaTextStyle?')
  final String dartType;
  
  /// The Rust type to use (e.g., 'String', 'i64', 'Option<Box<LuaTextStyle>>')
  final String rustType;
  
  /// Whether this property is required in Lua
  final bool required;
  
  /// Default value as a Lua expression (optional)
  final String? defaultValue;
  
  /// Whether this property is a child widget (single)
  final bool isChildWidget;
  
  /// Whether this property is a list of child widgets
  final bool isChildList;
  
  /// Whether this property is a callback
  final bool isCallback;
  
  /// Whether this property is a custom data class (with @LuaData)
  final bool isDataClass;
  
  /// For data class properties, the name of the nested class
  final String? nestedClassName;
  
  /// Whether the Dart type is nullable
  bool get isNullable => dartType.endsWith('?');
  
  /// The non-nullable Dart type
  String get nonNullableDartType => isNullable ? dartType.substring(0, dartType.length - 1) : dartType;
  
  const PropertyInfo({
    required this.name,
    required this.dartType,
    required this.rustType,
    this.required = false,
    this.defaultValue,
    this.isChildWidget = false,
    this.isChildList = false,
    this.isCallback = false,
    this.isDataClass = false,
    this.nestedClassName,
  });
}

/// Type information for built-in type mappings
class TypeInfo {
  final String dart;
  final String rust;
  final String lua;
  final String dartFromJson;
  final String dartToJson;
  
  const TypeInfo({
    required this.dart,
    required this.rust,
    required this.lua,
    required this.dartFromJson,
    required this.dartToJson,
  });
}

/// Maps Dart type names to their Rust and Lua equivalents
class TypeMapping {
  static const Map<String, TypeInfo> builtInTypes = {
    'String': TypeInfo(
      dart: 'String',
      rust: 'String',
      lua: 'string',
      dartFromJson: 'value as String',
      dartToJson: 'value',
    ),
    'int': TypeInfo(
      dart: 'int',
      rust: 'i64',
      lua: 'integer',
      dartFromJson: '(value as num).toInt()',
      dartToJson: 'value',
    ),
    'double': TypeInfo(
      dart: 'double',
      rust: 'f64',
      lua: 'number',
      dartFromJson: 'value as double',
      dartToJson: 'value',
    ),
    'bool': TypeInfo(
      dart: 'bool',
      rust: 'bool',
      lua: 'boolean',
      dartFromJson: 'value as bool',
      dartToJson: 'value',
    ),
    'num': TypeInfo(
      dart: 'num',
      rust: 'f64',
      lua: 'number',
      dartFromJson: 'value as num',
      dartToJson: 'value',
    ),
    'dynamic': TypeInfo(
      dart: 'dynamic',
      rust: 'Value',  // mlua::Value
      lua: 'any',
      dartFromJson: 'value',
      dartToJson: 'value',
    ),
  };
  
  /// Get type info for a Dart type, handling nullable types
  static TypeInfo? getForDartType(String dartType) {
    final cleanType = dartType.endsWith('?') 
      ? dartType.substring(0, dartType.length - 1) 
      : dartType;
    return builtInTypes[cleanType];
  }
  
  /// Check if a type is a built-in primitive
  static bool isBuiltInType(String type) {
    final cleanType = type.endsWith('?') ? type.substring(0, type.length - 1) : type;
    return builtInTypes.containsKey(cleanType);
  }
}
