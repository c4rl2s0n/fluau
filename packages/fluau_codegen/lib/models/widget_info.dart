/// Data models for the Lua plugin code generator.

/// One generative constructor exposed to Lua.
class LuaConstructorInfo {
  /// Dart constructor name; empty string = unnamed.
  final String dartName;

  /// Lua entry name (`Text`, `Text_styled`, …).
  final String luaName;

  /// Constructor parameters (Lua snapshot fields), in declaration order.
  final List<PropertyInfo> parameters;

  const LuaConstructorInfo({
    required this.dartName,
    required this.luaName,
    required this.parameters,
  });

  bool get isUnnamed => dartName.isEmpty;

  /// Tear-off / call site: `LuaFoo` or `LuaFoo.styled`.
  String dartCall(String className) =>
      isUnnamed ? className : '$className.$dartName';
}

/// Information about a Lua-exposable class (widget or data class)
class LuaClassInfo {
  final String name;
  final String dartClassName;
  final String rustStructName;

  /// Primary Lua widget / data name from `@LuaWidget` / `@LuaData`.
  final String luaName;

  final bool isWidget;
  final bool hasChildren;

  /// All generative constructors exposed to Lua.
  final List<LuaConstructorInfo> constructors;

  final String sourceFile;

  const LuaClassInfo({
    required this.name,
    required this.dartClassName,
    required this.rustStructName,
    required this.luaName,
    required this.isWidget,
    this.hasChildren = false,
    required this.constructors,
    required this.sourceFile,
  });

  /// Primary ctor params (unnamed if present, else first).
  List<PropertyInfo> get properties {
    if (constructors.isEmpty) return const [];
    final unnamed = constructors.where((c) => c.isUnnamed);
    if (unnamed.isNotEmpty) return unnamed.first.parameters;
    return constructors.first.parameters;
  }

  bool get hasProperties => properties.isNotEmpty;

  List<PropertyInfo> get childWidgetProperties =>
      properties.where((p) => p.isChildWidget).toList();

  List<PropertyInfo> get childListProperties =>
      properties.where((p) => p.isChildList).toList();

  List<PropertyInfo> get callbackProperties =>
      properties.where((p) => p.isCallback).toList();

  List<PropertyInfo> get dataClassProperties =>
      properties.where((p) => p.isDataClass).toList();
}

/// Constructor parameter / Lua snapshot field.
class PropertyInfo {
  /// Lua / JSON key (and usually the Dart param name).
  final String name;

  /// Dart parameter name for the constructor call.
  final String dartParamName;

  /// Whether this is a named Dart parameter (`{this.x}`) vs positional (`this.x`).
  /// Lua/JSON always use [name] as the key regardless.
  final bool isNamed;

  final String dartType;
  final String rustType;

  /// Required in Lua (non-nullable, no Dart default).
  final bool required;

  /// Param has a Dart default — omit from ctor call when JSON key absent.
  final bool hasConstructorDefault;

  /// Source text of the Dart default expression, when present.
  final String? defaultValueCode;

  final String? defaultValue;
  final bool isChildWidget;
  final bool isChildList;
  final bool isStringList;
  final bool isCallback;
  final bool isDataClass;
  final bool isEnum;
  final List<String>? enumValues;
  final String? typeSourceFile;
  final String? nestedClassName;

  bool get isNullable => dartType.endsWith('?');

  String get nonNullableDartType =>
      isNullable ? dartType.substring(0, dartType.length - 1) : dartType;

  /// Optional in Lua: nullable or has a constructor default.
  bool get isOptionalInLua => !required;

  /// Omit named arg when JSON key missing (non-null + Dart default).
  bool get omitWhenAbsent => hasConstructorDefault && !isNullable;

  const PropertyInfo({
    required this.name,
    required this.dartParamName,
    this.isNamed = true,
    required this.dartType,
    required this.rustType,
    this.required = false,
    this.hasConstructorDefault = false,
    this.defaultValueCode,
    this.defaultValue,
    this.isChildWidget = false,
    this.isChildList = false,
    this.isStringList = false,
    this.isCallback = false,
    this.isDataClass = false,
    this.isEnum = false,
    this.enumValues,
    this.typeSourceFile,
    this.nestedClassName,
  });
}

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
      rust: 'Value',
      lua: 'any',
      dartFromJson: 'value',
      dartToJson: 'value',
    ),
  };

  static TypeInfo? getForDartType(String dartType) {
    final cleanType =
        dartType.endsWith('?') ? dartType.substring(0, dartType.length - 1) : dartType;
    return builtInTypes[cleanType];
  }

  static bool isBuiltInType(String type) {
    final cleanType =
        type.endsWith('?') ? type.substring(0, type.length - 1) : type;
    return builtInTypes.containsKey(cleanType);
  }
}
