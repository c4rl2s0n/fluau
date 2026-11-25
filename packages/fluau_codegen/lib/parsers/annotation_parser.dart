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

class AnnotationParser {
  AnnotationParser();

  Future<List<LuaClassInfo>> parseDirectory(String dirPath) async {
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
    if (dartFiles.isEmpty) return [];

    final context = AnalysisContextCollection(includedPaths: [dirPath]);
    final allClasses = <LuaClassInfo>[];
    for (final filePath in dartFiles) {
      try {
        allClasses.addAll(await _parseFile(context, filePath));
      } catch (e) {
        print('Warning: Failed to parse $filePath: $e');
      }
    }
    return allClasses;
  }

  Future<List<LuaClassInfo>> _parseFile(
    AnalysisContextCollection context,
    String filePath,
  ) async {
    final session = context.contextFor(filePath).currentSession;
    final result = await session.getResolvedLibrary(filePath);
    if (result is! ResolvedLibraryResult) {
      print('Warning: Could not resolve library for $filePath');
      return [];
    }

    final classes = <LuaClassInfo>[];
    for (final element in result.element.classes) {
      final luaClass = _parseClass(element, filePath);
      if (luaClass != null) classes.add(luaClass);
    }
    return classes;
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
        final prop = _parseParameter(param);
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

  PropertyInfo? _parseParameter(FormalParameterElement param) {
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

    if (typeElement is EnumElement) {
      isEnum = true;
      enumValues = _getEnumValues(param.type);
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
    if (!isCallback &&
        (nonNullType == 'Map<String, dynamic>' ||
            nonNullType.startsWith('Map<String,'))) {
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
      typeSourceFile: typeSourceFile,
      nestedClassName: nestedClassName,
    );
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
