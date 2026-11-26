/// Annotation parser for Lua plugin code generation.
///
/// Exposable Lua shape = generative constructor parameters.
/// `@LuaProperty` / `@LuaCallback` / `@LuaChildren` on params are optional renames.

library fluau_codegen.parsers.annotation_parser;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../models/widget_info.dart';

/// Thrown when a `@LuaWidget` constructor parameter uses an unsupported type
/// (e.g. a Dart function/closure instead of an event payload map).
class LuaWidgetCodegenException implements Exception {
  LuaWidgetCodegenException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AnnotationParser {
  AnnotationParser();

  /// Error text when a `@LuaWidget` param is a Dart function/closure.
  static String closureParamError({
    required String className,
    required String paramName,
    required String dartType,
  }) {
    return '@LuaWidget parameter `$paramName` on `$className` cannot be a '
        'Dart function/closure (got `$dartType`). Fluau cannot pass live '
        'callbacks across the Lua↔Flutter bridge. Use `Map<String, dynamic>?` '
        '(event payload) and dispatch via `PluginEventScope.dispatch` from the '
        'widget; handle it in Lua `on_event`, or pass a Lua function that the '
        'runtime registers as a reserved `action` event.';
  }

  /// Error text when `@LuaCallback` is applied to a non-map type.
  static String luaCallbackNonMapError({
    required String className,
    required String paramName,
    required String dartType,
  }) {
    return '@LuaCallback on `$className.$paramName` requires '
        '`LuaEventPayload` / `Map<String, dynamic>` (event payload), '
        'got `$dartType`.';
  }

  /// Whether [dartType] / flags represent an unsupported Dart callable.
  static bool isUnsupportedClosureType({
    required String dartType,
    required bool isFunctionType,
    required bool isTypedefToFunction,
  }) {
    if (isFunctionType || isTypedefToFunction) return true;
    final nonNull =
        dartType.endsWith('?') ? dartType.substring(0, dartType.length - 1) : dartType;
    if (nonNull == 'Function' ||
        nonNull == 'VoidCallback' ||
        nonNull.startsWith('Function(') ||
        nonNull.contains(' Function(') ||
        nonNull.startsWith('ValueChanged<') ||
        nonNull.startsWith('ValueSetter<') ||
        nonNull.startsWith('FormFieldSetter<')) {
      return true;
    }
    return false;
  }

  /// Display-string check for event payload maps (`Map<String,…>` / `LuaEventPayload`).
  static bool isEventPayloadMapDisplay(String dartType) {
    final nonNull =
        dartType.endsWith('?') ? dartType.substring(0, dartType.length - 1) : dartType;
    if (nonNull == 'LuaEventPayload') return true;
    if (nonNull == 'Map<String, dynamic>' || nonNull.startsWith('Map<String,')) {
      return true;
    }
    return false;
  }

  /// Validates callback-related ctor params; throws [LuaWidgetCodegenException].
  static void validateCallbackParam({
    required String className,
    required String paramName,
    required String dartType,
    required bool isFunctionType,
    required bool isTypedefToFunction,
    String? annotationKind,
    required bool isEventPayloadMap,
  }) {
    if (isUnsupportedClosureType(
      dartType: dartType,
      isFunctionType: isFunctionType,
      isTypedefToFunction: isTypedefToFunction,
    )) {
      throw LuaWidgetCodegenException(
        closureParamError(
          className: className,
          paramName: paramName,
          dartType: dartType,
        ),
      );
    }
    if (annotationKind == 'LuaCallback' && !isEventPayloadMap) {
      throw LuaWidgetCodegenException(
        luaCallbackNonMapError(
          className: className,
          paramName: paramName,
          dartType: dartType,
        ),
      );
    }
  }

  Future<WidgetParseResult> parseDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw ArgumentError('Directory does not exist: $dirPath');
    }

    final dartFiles = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity.path);
      }
    }
    if (dartFiles.isEmpty) {
      return const WidgetParseResult(classes: [], enums: []);
    }

    final context = AnalysisContextCollection(includedPaths: [dirPath]);
    final allClasses = <LuaClassInfo>[];
    final enumsByDart = <String, LuaEnumInfo>{};

    for (final filePath in dartFiles) {
      try {
        final parsed = await _parseFile(context, filePath);
        allClasses.addAll(parsed.classes);
        for (final e in parsed.enums) {
          enumsByDart.putIfAbsent(e.dartName, () => e);
        }
      } on LuaWidgetCodegenException {
        rethrow;
      } catch (e) {
        print('Warning: Failed to parse $filePath: $e');
      }
    }

    // Enums discovered only via widget params (no @LuaEnum) still get a table.
    for (final luaClass in allClasses) {
      for (final ctor in luaClass.constructors) {
        for (final prop in ctor.parameters) {
          if (!prop.isEnum || prop.enumValues == null) continue;
          final dartName = prop.nonNullableDartType;
          enumsByDart.putIfAbsent(
            dartName,
            () => LuaEnumInfo(
              dartName: dartName,
              luaName: prop.enumLuaName ?? dartName,
              values: List<String>.from(prop.enumValues!),
              sourceFile: prop.typeSourceFile ?? '',
            ),
          );
        }
      }
    }

    final enums = enumsByDart.values.toList()
      ..sort((a, b) => a.luaName.compareTo(b.luaName));
    return WidgetParseResult(classes: allClasses, enums: enums);
  }

  Future<({List<LuaClassInfo> classes, List<LuaEnumInfo> enums})> _parseFile(
    AnalysisContextCollection context,
    String filePath,
  ) async {
    final session = context.contextFor(filePath).currentSession;
    final result = await session.getResolvedLibrary(filePath);
    if (result is! ResolvedLibraryResult) {
      print('Warning: Could not resolve library for $filePath');
      return (classes: <LuaClassInfo>[], enums: <LuaEnumInfo>[]);
    }

    final classes = <LuaClassInfo>[];
    for (final element in result.element.classes) {
      final luaClass = _parseClass(element, filePath);
      if (luaClass != null) classes.add(luaClass);
    }

    final enums = <LuaEnumInfo>[];
    for (final element in result.element.enums) {
      final info = _parseAnnotatedEnum(element, filePath);
      if (info != null) enums.add(info);
    }
    return (classes: classes, enums: enums);
  }

  LuaEnumInfo? _parseAnnotatedEnum(EnumElement element, String sourceFile) {
    String? luaName;
    var hasAnno = false;
    for (final annotation in element.metadata.annotations) {
      final constant = annotation.computeConstantValue();
      final typeName = constant?.type?.getDisplayString();
      if (typeName == 'LuaEnum') {
        hasAnno = true;
        final namedArgs = _getAnnotationNamedArgs(constant);
        luaName = namedArgs['name'] as String?;
        break;
      }
    }
    if (!hasAnno) return null;

    final dartName = element.name ?? '';
    if (dartName.isEmpty) return null;
    final values = _enumValuesFromElement(element);
    if (values.isEmpty) return null;

    return LuaEnumInfo(
      dartName: dartName,
      luaName: luaName ?? dartName,
      values: values,
      sourceFile: sourceFile,
    );
  }

  String? _luaEnumName(EnumElement element) {
    for (final annotation in element.metadata.annotations) {
      final constant = annotation.computeConstantValue();
      final typeName = constant?.type?.getDisplayString();
      if (typeName == 'LuaEnum') {
        final namedArgs = _getAnnotationNamedArgs(constant);
        return (namedArgs['name'] as String?) ?? element.name;
      }
    }
    return element.name;
  }

  LuaClassInfo? _parseClass(ClassElement classElement, String sourceFile) {
    bool? isWidget;
    bool hasChildren = false;
    String? luaName;

    for (final annotation in classElement.metadata.annotations) {
      final constant = annotation.computeConstantValue();
      final typeName = constant?.type?.getDisplayString();
      if (typeName == 'LuaWidget') {
        isWidget = true;
        final namedArgs = _getAnnotationNamedArgs(constant);
        luaName = namedArgs['name'] as String?;
        hasChildren = namedArgs['hasChildren'] as bool? ?? false;
        break;
      } else if (typeName == 'LuaData') {
        isWidget = false;
        final namedArgs = _getAnnotationNamedArgs(constant);
        luaName = namedArgs['name'] as String?;
        break;
      }
    }

    if (isWidget == null) return null;

    final className = classElement.name ?? '';
    if (className.isEmpty) return null;

    // @LuaWidget catalog entries must be Flutter Widgets.
    if (isWidget && !_isFlutterWidget(classElement)) {
      print(
        'Error: $className has @LuaWidget but does not extend Widget '
        '(use StatelessWidget / StatefulWidget). Skipping.',
      );
      return null;
    }

    final baseClassName =
        className.startsWith('Lua') ? className.substring(3) : className;
    final rustStructName = 'Lua$baseClassName';
    final luaClassName = luaName ?? className;

    final constructors = <LuaConstructorInfo>[];
    for (final ctor in classElement.constructors) {
      if (!ctor.isGenerative || ctor.isFactory) continue;
      // Skip private named constructors (name is `new` for unnamed).
      final ctorName = ctor.name ?? 'new';
      if (ctorName != 'new' && ctorName.startsWith('_')) continue;

      final params = <PropertyInfo>[];
      for (final param in ctor.formalParameters) {
        final prop = _parseParameter(param, className: className);
        if (prop != null) params.add(prop);
      }

      final dartCtorName = ctorName == 'new' ? '' : ctorName;
      final derivedLua = dartCtorName.isEmpty
          ? luaClassName
          : '${luaClassName}_$dartCtorName';

      constructors.add(
        LuaConstructorInfo(
          dartName: dartCtorName,
          luaName: derivedLua,
          parameters: params,
        ),
      );
    }

    if (constructors.isEmpty) {
      print(
        'Warning: $className has @LuaWidget/@LuaData but no generative '
        'constructors — skipping',
      );
      return null;
    }

    final anyChildren = constructors.any(
      (c) => c.parameters.any((p) => p.isChildList || p.isChildWidget),
    );

    return LuaClassInfo(
      name: className,
      dartClassName: className,
      rustStructName: rustStructName,
      luaName: luaClassName,
      isWidget: isWidget,
      hasChildren: hasChildren || anyChildren,
      constructors: constructors,
      sourceFile: sourceFile,
    );
  }

  PropertyInfo? _parseParameter(
    FormalParameterElement param, {
    required String className,
  }) {
    final rawName = param.name;
    if (rawName == null || rawName.isEmpty || rawName.startsWith('_')) {
      return null;
    }

    final dartType = param.type.getDisplayString();
    final nonNullType =
        dartType.endsWith('?') ? dartType.substring(0, dartType.length - 1) : dartType;

    // Skip Flutter Key / super.key (not a Lua concern).
    if (_isFlutterKeyType(nonNullType)) return null;

    String? annotationKind;
    String? luaNameOverride;
    for (final annotation in param.metadata.annotations) {
      final constant = annotation.computeConstantValue();
      final typeName = constant?.type?.getDisplayString();
      if (typeName == 'LuaProperty' ||
          typeName == 'LuaCallback' ||
          typeName == 'LuaChildren') {
        annotationKind = typeName;
        final namedArgs = _getAnnotationNamedArgs(constant);
        luaNameOverride = namedArgs['name'] as String?;
        break;
      }
    }

    final isEventPayloadMap = _isEventPayloadMap(param.type);
    final isFunctionType = param.type is FunctionType;
    final isTypedefToFunction = _isTypedefToFunction(param.type);

    validateCallbackParam(
      className: className,
      paramName: rawName,
      dartType: dartType,
      isFunctionType: isFunctionType,
      isTypedefToFunction: isTypedefToFunction,
      annotationKind: annotationKind,
      isEventPayloadMap: isEventPayloadMap,
    );

    final isNullable = dartType.endsWith('?');
    final hasDefault = param.hasDefaultValue;
    final required = !isNullable && !hasDefault;

    var isCallback = annotationKind == 'LuaCallback';
    var isChildList = annotationKind == 'LuaChildren';
    var isChildWidget = false;
    var isStringList = false;
    var isDataClass = false;
    var isEnum = false;
    List<String>? enumValues;
    String? typeSourceFile;
    String? nestedClassName;

    final typeElement = param.type.element;

    String? enumLuaName;
    if (typeElement is EnumElement) {
      isEnum = true;
      enumValues = _enumValuesFromElement(typeElement);
      enumLuaName = _luaEnumName(typeElement);
      typeSourceFile = _elementSourcePath(typeElement);
    }

    if (typeElement is ClassElement) {
      for (final annotation in typeElement.metadata.annotations) {
        final typeName =
            annotation.computeConstantValue()?.type?.getDisplayString();
        if (typeName == 'LuaData') {
          isDataClass = true;
          nestedClassName = typeElement.name;
          typeSourceFile = _elementSourcePath(typeElement);
        }
        if (typeName == 'LuaWidget') {
          isChildWidget = true;
          nestedClassName = typeElement.name;
        }
      }
    }

    if (param.type is InterfaceType) {
      final interfaceType = param.type as InterfaceType;
      final typeName = interfaceType.element.name;
      if (typeName == 'Widget' || _typeIsFlutterWidget(param.type)) {
        isChildWidget = true;
      } else if (typeName == 'List') {
        final typeArgs = interfaceType.typeArguments;
        if (typeArgs.isNotEmpty) {
          final argType = typeArgs.first;
          final argElement = argType.element;
          if (argElement?.name == 'Widget' || _typeIsFlutterWidget(argType)) {
            isChildList = true;
          } else if (argElement?.name == 'String') {
            isStringList = true;
          } else if (argElement is ClassElement) {
            for (final annotation in argElement.metadata.annotations) {
              final annName =
                  annotation.computeConstantValue()?.type?.getDisplayString();
              if (annName == 'LuaWidget') {
                isChildList = true;
                nestedClassName = argElement.name;
              }
            }
            // Concrete Widget subclasses in List<MyWidget>
            if (!isChildList && _isFlutterWidget(argElement)) {
              isChildList = true;
              nestedClassName = argElement.name;
            }
          }
        }
      } else if (typeElement is ClassElement && _isFlutterWidget(typeElement)) {
        isChildWidget = true;
        nestedClassName = typeElement.name;
      }
    }

    // Infer callback: Map<String, dynamic>
    if (!isCallback && isEventPayloadMap) {
      isCallback = true;
    }

    if (annotationKind == 'LuaCallback') isCallback = true;
    if (annotationKind == 'LuaChildren') {
      isChildList = true;
      isChildWidget = false;
    }

    final rustType = _rustTypeFor(
      isCallback: isCallback,
      isChildList: isChildList,
      isStringList: isStringList,
      isChildWidget: isChildWidget,
      isDataClass: isDataClass,
      isEnum: isEnum,
      isNullable: isNullable,
      nestedClassName: nestedClassName,
      nonNullableType: nonNullType,
    );

    return PropertyInfo(
      name: luaNameOverride ?? rawName,
      dartParamName: rawName,
      isNamed: param.isNamed,
      dartType: dartType,
      rustType: rustType,
      required: required,
      hasConstructorDefault: hasDefault,
      defaultValueCode: hasDefault ? param.defaultValueCode : null,
      isChildWidget: isChildWidget,
      isChildList: isChildList,
      isStringList: isStringList,
      isCallback: isCallback,
      isDataClass: isDataClass,
      isEnum: isEnum,
      enumValues: enumValues,
      enumLuaName: enumLuaName,
      typeSourceFile: typeSourceFile,
      nestedClassName: nestedClassName,
    );
  }

  bool _isTypedefToFunction(DartType type) {
    final alias = type.alias;
    if (alias == null) return false;
    return alias.element.aliasedType is FunctionType;
  }

  /// True for `Map<String, …>`, `LuaEventPayload`, or typedefs that alias to those.
  bool _isEventPayloadMap(DartType type) {
    if (isEventPayloadMapDisplay(type.getDisplayString())) return true;
    if (_isStringKeyedMapType(type)) return true;

    final alias = type.alias;
    if (alias != null) {
      final aliased = alias.element.aliasedType;
      if (isEventPayloadMapDisplay(aliased.getDisplayString())) return true;
      if (_isStringKeyedMapType(aliased)) return true;
      final aliasName = alias.element.name;
      if (aliasName == 'LuaEventPayload') return true;
    }
    return false;
  }

  bool _isStringKeyedMapType(DartType type) {
    if (type is! InterfaceType) return false;
    if (type.element.name != 'Map') return false;
    if (type.typeArguments.isEmpty) return false;
    final keyDisplay = type.typeArguments.first.getDisplayString();
    final keyNonNull = keyDisplay.endsWith('?')
        ? keyDisplay.substring(0, keyDisplay.length - 1)
        : keyDisplay;
    return keyNonNull == 'String';
  }

  bool _isFlutterKeyType(String nonNullType) {
    return nonNullType == 'Key' ||
        nonNullType == 'GlobalKey' ||
        nonNullType == 'ValueKey' ||
        nonNullType == 'UniqueKey' ||
        nonNullType == 'ObjectKey' ||
        nonNullType == 'PageStorageKey' ||
        nonNullType.startsWith('GlobalKey<') ||
        nonNullType.startsWith('ValueKey<') ||
        nonNullType.startsWith('PageStorageKey<');
  }

  /// Whether [element] is a Flutter [Widget] (or subclass).
  bool _isFlutterWidget(ClassElement element) {
    if (element.name == 'Widget') return true;
    for (final type in element.allSupertypes) {
      if (type.element.name == 'Widget') return true;
    }
    return false;
  }

  bool _typeIsFlutterWidget(DartType type) {
    final element = type.element;
    if (element is ClassElement) return _isFlutterWidget(element);
    return false;
  }

  String _rustTypeFor({
    required bool isCallback,
    required bool isChildList,
    required bool isStringList,
    required bool isChildWidget,
    required bool isDataClass,
    required bool isEnum,
    required bool isNullable,
    required String? nestedClassName,
    required String nonNullableType,
  }) {
    if (isCallback) return isNullable ? 'Option<String>' : 'String';
    if (isChildList) return 'Vec<Box<dyn LuaWidget>>';
    if (isStringList) {
      return isNullable ? 'Option<Vec<String>>' : 'Vec<String>';
    }
    if (isChildWidget) {
      return isNullable
          ? 'Option<Box<dyn LuaWidget>>'
          : 'Box<dyn LuaWidget>';
    }
    if (isDataClass) {
      final className = nestedClassName ?? nonNullableType;
      return isNullable
          ? 'Option<Box<Lua$className>>'
          : 'Box<Lua$className>';
    }
    if (isEnum) return isNullable ? 'Option<String>' : 'String';
    return _mapDartTypeToRust(nonNullableType, isNullable);
  }

  String? _elementSourcePath(Element element) {
    try {
      final library = element.library;
      if (library == null) return null;
      final fullName = library.firstFragment.source.fullName;
      if (fullName.isNotEmpty) return fullName;
    } catch (_) {}
    return null;
  }

  String _mapDartTypeToRust(String dartType, bool isNullable) {
    final prefix = isNullable ? 'Option<' : '';
    final suffix = isNullable ? '>' : '';
    switch (dartType) {
      case 'String':
        return '$prefix String$suffix';
      case 'int':
        return '$prefix i64$suffix';
      case 'double':
        return '$prefix f64$suffix';
      case 'bool':
        return '$prefix bool$suffix';
      case 'num':
        return '$prefix f64$suffix';
      case 'dynamic':
        return '$prefix mlua::Value$suffix';
      default:
        return '$prefix String$suffix';
    }
  }

  Map<String, dynamic> _getAnnotationNamedArgs(DartObject? constant) {
    if (constant == null) return {};
    final result = <String, dynamic>{};
    for (final fieldName in ['name', 'required', 'defaultValue', 'hasChildren']) {
      try {
        final value = constant.getField(fieldName);
        if (value != null) result[fieldName] = _dartObjectToValue(value);
      } catch (_) {}
    }
    return result;
  }

  dynamic _dartObjectToValue(DartObject? obj) {
    if (obj == null || obj.isNull) return null;
    try {
      if (obj.toBoolValue() != null) return obj.toBoolValue();
    } catch (_) {}
    try {
      if (obj.toIntValue() != null) return obj.toIntValue();
    } catch (_) {}
    try {
      if (obj.toDoubleValue() != null) return obj.toDoubleValue();
    } catch (_) {}
    try {
      final str = obj.toStringValue();
      if (str != null) return str;
    } catch (_) {}
    return null;
  }

  List<String> _getEnumValues(DartType type) {
    final element = type.element;
    if (element is! EnumElement) return [];
    return _enumValuesFromElement(element);
  }

  List<String> _enumValuesFromElement(EnumElement element) {
    try {
      final constants =
          element.fields.where((f) => f.isConst && f.isEnumConstant);
      return constants
          .map((c) => c.name ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
