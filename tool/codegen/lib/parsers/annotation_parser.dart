/// Annotation parser for Lua plugin code generation
///
/// Parses Dart source files to extract classes with LuaWidget/LuaData annotations
/// and their properties with LuaProperty/LuaChildren/LuaCallback annotations.

library lua_plugin_codegen.parsers.annotation_parser;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as path;

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
    final context = AnalysisContextCollection(
      includedPaths: [dirPath],
    );

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
    final result = context.contextFor(filePath).currentSession
        .getResolvedLibrary(filePath);

    if (result is! ResolvedLibraryResult) {
      print('Warning: Could not resolve library for $filePath');
      return [];
    }

    final library = result.library;
    if (library == null) {
      print('Warning: No library found for $filePath');
      return [];
    }

    // Find all classes with LuaWidget or LuaData annotations
    final classes = <LuaClassInfo>[];
    for (final element in library.definingCompilationUnit.topLevelElements) {
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

    for (final annotation in classElement.metadata) {
      final constant = annotation.computeConstantValue();
      if (constant?.type?.getDisplayString(withNullability: false) == 'LuaWidget') {
        isWidget = true;
        // Extract annotation parameters
        final namedArgs = constant?.toMap() ?? {};
        luaName = namedArgs['name']?.toStringValue();
        hasChildren = namedArgs['hasChildren']?.toBoolValue() ?? false;
        break;
      } else if (constant?.type?.getDisplayString(withNullability: false) == 'LuaData') {
        isWidget = false;
        final namedArgs = constant?.toMap() ?? {};
        luaName = namedArgs['name']?.toStringValue();
        break;
      }
    }

    // If no LuaWidget or LuaData annotation, skip this class
    if (!isWidget && luaName == null) {
      // Also check if it's annotated with LuaData without checking name first
      for (final annotation in classElement.metadata) {
        final constant = annotation.computeConstantValue();
        if (constant?.type?.getDisplayString(withNullability: false) == 'LuaData') {
          isWidget = false;
          final namedArgs = constant?.toMap() ?? {};
          luaName = namedArgs['name']?.toStringValue();
          break;
        }
      }
      if (luaName == null && !isWidget) {
        return null;
      }
    }

    if (!isWidget && luaName == null) {
      return null;
    }

    // Parse properties
    final properties = <PropertyInfo>[];
    for (final field in classElement.fields) {
      // Skip synthetic fields and private fields
      if (field.isSynthetic || field.name.startsWith('_')) {
        continue;
      }

      final propInfo = _parseProperty(field);
      if (propInfo != null) {
        properties.add(propInfo);
      }
    }

    // Determine Rust struct name
    final className = classElement.name;
    final rustStructName = 'Lua$className';
    final dartClassName = className;
    final luaClassName = luaName ?? className;

    return LuaClassInfo(
      name: className,
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

    for (final annotation in field.metadata) {
      final constant = annotation.computeConstantValue();
      final typeName = constant?.type?.getDisplayString(withNullability: false);

      if (typeName == 'LuaProperty') {
        annotationName = 'LuaProperty';
        final namedArgs = constant?.toMap() ?? {};
        required = namedArgs['required']?.toBoolValue() ?? false;
        defaultValue = namedArgs['defaultValue']?.toStringValue();
        propertyName = namedArgs['name']?.toStringValue();
        break;
      } else if (typeName == 'LuaChildren') {
        annotationName = 'LuaChildren';
        final namedArgs = constant?.toMap() ?? {};
        propertyName = namedArgs['name']?.toStringValue();
        break;
      } else if (typeName == 'LuaCallback') {
        annotationName = 'LuaCallback';
        final namedArgs = constant?.toMap() ?? {};
        propertyName = namedArgs['name']?.toStringValue();
        break;
      }
    }

    // If no relevant annotation, skip this property
    if (annotationName == null) {
      return null;
    }

    final fieldName = propertyName ?? field.name;
    final dartType = field.type.getDisplayString(withNullability: true);
    final isNullable = dartType.endsWith('?');
    final nonNullableType = isNullable ? dartType.substring(0, dartType.length - 1) : dartType;

    // Determine the property type category
    final typeElement = field.type.element;

    // Check if it's an enum
    bool isEnum = false;
    List<String>? enumValues;
    if (typeElement is EnumElement) {
      isEnum = true;
      enumValues = typeElement.constants.map((c) => c.name).toList();
    }

    // Check if it's a LuaData class (custom data class)
    bool isDataClass = false;
    String? nestedClassName;
    if (typeElement is ClassElement) {
      // Check if this class has @LuaData annotation
      for (final annotation in typeElement.metadata) {
        final constant = annotation.computeConstantValue();
        if (constant?.type?.getDisplayString(withNullability: false) == 'LuaData') {
          isDataClass = true;
          nestedClassName = typeElement.name;
          break;
        }
      }
    }

    // Check if it's a LuaWidget class (child widget)
    bool isChildWidget = false;
    bool isChildList = false;
    if (typeElement is ClassElement) {
      for (final annotation in typeElement.metadata) {
        final constant = annotation.computeConstantValue();
        if (constant?.type?.getDisplayString(withNullability: false) == 'LuaWidget') {
          // Check if it's a List<LuaWidget>
          if (field.type is InterfaceType && field.type.element.name == 'List') {
            isChildList = true;
          } else {
            isChildWidget = true;
          }
          nestedClassName = typeElement.name;
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
    } else if (isChildWidget) {
      rustType = isNullable ? 'Option<Box<dyn LuaWidget>>' : 'Box<dyn LuaWidget>';
    } else if (isDataClass) {
      final className = nestedClassName ?? nonNullableType;
      rustType = isNullable ? 'Option<Box<Lua$className>>' : 'Box<Lua$className>';
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
}
