/// Annotation parser for Lua plugin code generation
///
/// Parses Dart source files to extract classes with LuaWidget/LuaData annotations
/// and their properties with LuaProperty/LuaChildren/LuaCallback annotations.
///
/// Compatible with analyzer 14.x

library lua_plugin_codegen.parsers.annotation_parser;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/constant/value.dart';

import '../models/widget_info.dart';

/// Parses Dart files for LuaWidget and LuaData annotations
class AnnotationParser {
  /// Create a new parser
  AnnotationParser();

  /// Parse all Dart files in a directory for Lua classes
  Future<List<LuaClassInfo>> parseDirectory(String dirPath) async {
    final dir = Directory(dirPath);

    if (!await dir.exists()) {
      throw ArgumentError('Directory does not exist: $dirPath');
    }

    // Get all Dart files recursively
    final dartFiles = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity.path);
      }
    }

    if (dartFiles.isEmpty) {
      return [];
    }

    // Create analysis context for the directory
    // In analyzer 14, sdkPath is optional and will use the default SDK if not provided
    final context = AnalysisContextCollection(includedPaths: [dirPath]);

    // Parse each file
    final allClasses = <LuaClassInfo>[];
    for (final filePath in dartFiles) {
      try {
        final classes = await _parseFile(context, filePath);
        allClasses.addAll(classes);
      } catch (e) {
        print('Warning: Failed to parse $filePath: $e');
      }
    }

    return allClasses;
  }

  /// Parse a single Dart file
  Future<List<LuaClassInfo>> _parseFile(
    AnalysisContextCollection context,
    String filePath,
  ) async {
    // Get the analysis result for this file
    final session = context.contextFor(filePath).currentSession;
    final result = await session.getResolvedLibrary(filePath);

    if (result is! ResolvedLibraryResult) {
      print('Warning: Could not resolve library for $filePath');
      return [];
    }

    final library = result.element; // element is non-nullable in ResolvedLibraryResult

    // Find all classes with LuaWidget or LuaData annotations
    final classes = <LuaClassInfo>[];

    // In analyzer 14, we can get top-level declarations directly from LibraryElement
    final allElements = <Element>[...library.classes, ...library.enums];
    
    // Add functions and variables (these lists are non-nullable)
    allElements.addAll(library.topLevelFunctions);
    allElements.addAll(library.topLevelVariables);

    for (final element in allElements) {
      if (element is ClassElement) {
        final luaClass = _parseClass(element, filePath);
        if (luaClass != null) {
          classes.add(luaClass);
        }
      }
    }

    return classes;
  }

  /// Parse a class element into LuaClassInfo
  LuaClassInfo? _parseClass(ClassElement classElement, String sourceFile) {
    // Check for @LuaWidget or @LuaData annotation
    bool isWidget = false;
    bool hasChildren = false;
    String? luaName;

    // In analyzer 14, metadata is a Metadata object with .annotations list
    for (final annotation in classElement.metadata.annotations) {
      final constant = annotation.computeConstantValue();
      final typeName = constant?.type?.getDisplayString();

      if (typeName == 'LuaWidget') {
        isWidget = true;
        // Extract annotation parameters
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

    // If no LuaWidget or LuaData annotation, skip this class
    if (!isWidget && luaName == null) {
      return null;
    }

    // Parse properties
    final properties = <PropertyInfo>[];
    for (final field in classElement.fields) {
      // In analyzer 14, isSynthetic is removed
      // Use name to check for private fields instead
      // field.name is String? so we need null check
      final fieldName = field.name;
      if (fieldName == null || fieldName.startsWith('_')) {
        continue;
      }

      final propInfo = _parseProperty(field);
      if (propInfo != null) {
        properties.add(propInfo);
      }
    }

    // Determine Rust struct name
    final className = classElement.name; // className is String?
    // Remove "Lua" prefix from class name if present to avoid double prefix
    final baseClassName = className != null && className.startsWith('Lua')
        ? className.substring(3)
        : className ?? '';
    final rustStructName = 'Lua$baseClassName';
    final dartClassName = className ?? '';
    final luaClassName = luaName ?? dartClassName;

    return LuaClassInfo(
      name: dartClassName,
      dartClassName: dartClassName,
      rustStructName: rustStructName,
      luaName: luaClassName,
      isWidget: isWidget,
      hasChildren: hasChildren,
      properties: properties,
      sourceFile: sourceFile,
    );
  }

  /// Parse a field element into PropertyInfo
  PropertyInfo? _parseProperty(FieldElement field) {
    // Check which annotation this field has
    String? annotationName;
    bool required = false;
    String? defaultValue;
    String? propertyName;

    // In analyzer 14, metadata is a Metadata object with .annotations list
    for (final annotation in field.metadata.annotations) {
      final constant = annotation.computeConstantValue();
      final typeName = constant?.type?.getDisplayString();

      if (typeName == 'LuaProperty') {
        annotationName = 'LuaProperty';
        final namedArgs = _getAnnotationNamedArgs(constant);
        required = namedArgs['required'] as bool? ?? false;
        defaultValue = namedArgs['defaultValue'] as String?;
        propertyName = namedArgs['name'] as String?;
        break;
      } else if (typeName == 'LuaChildren') {
        annotationName = 'LuaChildren';
        final namedArgs = _getAnnotationNamedArgs(constant);
        propertyName = namedArgs['name'] as String?;
        break;
      } else if (typeName == 'LuaCallback') {
        annotationName = 'LuaCallback';
        final namedArgs = _getAnnotationNamedArgs(constant);
        propertyName = namedArgs['name'] as String?;
        break;
      }
    }

    // If no relevant annotation, skip this property
    if (annotationName == null) {
      return null;
    }

    final fieldName = propertyName ?? field.name ?? '';
    // In analyzer 14, getDisplayString doesn't require withNullability parameter
    final dartType = field.type.getDisplayString();
    final isNullable = dartType.endsWith('?');
    final nonNullableType = isNullable
        ? dartType.substring(0, dartType.length - 1)
        : dartType;

    // Determine the property type category
    final typeElement = field.type.element;

    // Check if it's an enum
    bool isEnum = false;
    List<String>? enumValues;
    if (typeElement is EnumElement) {
      isEnum = true;
      enumValues = _getEnumValues(field.type);
    }

    // Check if it's a LuaData class (custom data class)
    bool isDataClass = false;
    String? nestedClassName;
    if (typeElement is ClassElement) {
      // Check if this class has @LuaData annotation
      for (final annotation in typeElement.metadata.annotations) {
        final constant = annotation.computeConstantValue();
        final typeName = constant?.type?.getDisplayString();
        if (typeName == 'LuaData') {
          isDataClass = true;
          nestedClassName = typeElement.name; // name is String?
          break;
        }
      }
    }

    // Check if it's a LuaWidget class (child widget)
    bool isChildWidget = false;
    bool isChildList = false;
    bool isStringList = false;

    // Check if the field type is LuaWidgetInterface or List<LuaWidgetInterface>
    // For resolved types, element should be non-null
    if (field.type.element?.name == 'LuaWidgetInterface') {
      // Direct LuaWidgetInterface type
      isChildWidget = true;
    } else if (field.type is InterfaceType) {
      // Check if it's List<T> where T is LuaWidgetInterface or a LuaWidget
      final interfaceType = field.type as InterfaceType;
      // InterfaceType.element is non-nullable for resolved types
      if (interfaceType.element.name == 'List') {
        // This is a List type, check its type arguments
        final typeArgs = interfaceType.typeArguments;
        if (typeArgs.isNotEmpty) {
          final argType = typeArgs.first;
          final argElement = argType.element; // element is Element? (nullable)

          // Check if the list element type is LuaWidgetInterface
          if (argElement != null && argElement.name == 'LuaWidgetInterface') {
            isChildList = true;
          } else if (argElement != null && argElement.name == 'String') {
            isStringList = true;
          } else if (argElement is ClassElement) {
            // Check if it's a LuaWidget class
            for (final annotation in argElement.metadata.annotations) {
              final constant = annotation.computeConstantValue();
              final typeName = constant?.type?.getDisplayString();
              if (typeName == 'LuaWidget') {
                isChildList = true;
                nestedClassName = argElement.name; // name is String?
                break;
              }
            }
          }
        }
      }
    } else if (typeElement is ClassElement) {
      // Check if this class is a LuaWidget
      for (final annotation in typeElement.metadata.annotations) {
        final constant = annotation.computeConstantValue();
        final typeName = constant?.type?.getDisplayString();
        if (typeName == 'LuaWidget') {
          // Single child widget
          isChildWidget = true;
          nestedClassName = typeElement.name; // name is String?
          break;
        }
      }
    }

    // Check if it's a callback (String type with @LuaCallback)
    bool isCallback = annotationName == 'LuaCallback';

    // Determine Rust type
    String rustType;
    if (isCallback) {
      rustType = isNullable ? 'Option<String>' : 'String';
    } else if (isChildList) {
      rustType = 'Vec<Box<dyn LuaWidget>>';
    } else if (isStringList) {
      rustType = isNullable ? 'Option<Vec<String>>' : 'Vec<String>';
    } else if (isChildWidget) {
      rustType = isNullable
          ? 'Option<Box<dyn LuaWidget>>'
          : 'Box<dyn LuaWidget>';
    } else if (isDataClass) {
      final className = nestedClassName ?? nonNullableType;
      rustType = isNullable
          ? 'Option<Box<Lua$className>>'
          : 'Box<Lua$className>';
    } else if (isEnum) {
      rustType = isNullable ? 'Option<String>' : 'String';
    } else {
      // Primitive type - map from Dart to Rust
      rustType = _mapDartTypeToRust(nonNullableType, isNullable);
    }

    return PropertyInfo(
      name: fieldName,
      dartType: dartType,
      rustType: rustType,
      required: required,
      defaultValue: defaultValue,
      isChildWidget: isChildWidget,
      isChildList: isChildList,
      isStringList: isStringList,
      isCallback: isCallback,
      isDataClass: isDataClass,
      isEnum: isEnum,
      enumValues: enumValues,
      nestedClassName: nestedClassName,
    );
  }

  /// Map Dart primitive type to Rust type
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
        // Fallback to String for unknown types
        return '$prefix String$suffix';
    }
  }

  /// Get named arguments from an annotation constant value
  Map<String, dynamic> _getAnnotationNamedArgs(DartObject? constant) {
    if (constant == null) return {};

    final result = <String, dynamic>{};

    // In analyzer 14, we need to access fields differently
    // Try common field names: name, required, defaultValue, hasChildren
    final fieldNames = ['name', 'required', 'defaultValue', 'hasChildren'];
    for (final fieldName in fieldNames) {
      try {
        final value = constant.getField(fieldName);
        if (value != null) {
          result[fieldName] = _dartObjectToValue(value);
        }
      } catch (_) {
        // Field doesn't exist, skip it
      }
    }

    return result;
  }

  /// Convert a DartObject to a Dart value
  dynamic _dartObjectToValue(DartObject? obj) {
    if (obj == null) return null;

    if (obj.isNull) return null;

    // Try to get values in order of preference
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

  /// Get enum constant names from an EnumElement
  List<String> _getEnumValues(DartType type) {
    final element = type.element;
    if (element is! EnumElement) return [];

    try {
      // In analyzer 14, enum constants can be accessed via the enum's fields
      final constants = element.fields.where((f) => f.isConst && f.isEnumConstant);
      return constants.map((c) => c.name ?? '').where((n) => n.isNotEmpty).toList();
    } catch (e) {
      return [];
    }
  }
}
