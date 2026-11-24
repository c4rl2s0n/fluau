/// Parses @LuaCapability and @LuaCapabilityDto from Dart sources.

library;

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:path/path.dart' as p;

import '../models/capability_info.dart';

class CapabilityParser {
  Future<CapabilityParseResult> parseDirectory(String dirPath) async {
    final dir = Directory(dirPath);
    if (!await dir.exists()) {
      throw ArgumentError('Directory does not exist: $dirPath');
    }

    final dartFiles = <String>[];
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.g.dart')) {
        dartFiles.add(entity.path);
      }
    }
    if (dartFiles.isEmpty) {
      return CapabilityParseResult(capabilities: [], dtos: []);
    }

    final context = AnalysisContextCollection(
      includedPaths: [p.normalize(p.absolute(dirPath))],
    );

    final capabilities = <CapabilityInfo>[];
    final dtos = <CapabilityDtoInfo>[];
    final dtoNames = <String>{};

    for (final filePath in dartFiles) {
      try {
        final session = context.contextFor(filePath).currentSession;
        final result = await session.getResolvedLibrary(filePath);
        if (result is! ResolvedLibraryResult) continue;
        final library = result.element;

        for (final element in library.classes) {
          final cap = _parseCapability(element, filePath);
          if (cap != null) capabilities.add(cap);

          final dto = _parseDto(element, filePath);
          if (dto != null) {
            dtos.add(dto);
            dtoNames.add(dto.className);
          }
        }
      } catch (e) {
        print('Warning: Failed to parse $filePath: $e');
      }
    }

    _markNestedDtos(dtos, dtoNames);
    return CapabilityParseResult(capabilities: capabilities, dtos: dtos);
  }

  /// Parse a single resolved library (used by build_runner).
  CapabilityParseResult parseLibrary(
    LibraryElement library, {
    String sourceFile = '',
  }) {
    final capabilities = <CapabilityInfo>[];
    final dtos = <CapabilityDtoInfo>[];
    final dtoNames = <String>{};

    for (final element in library.classes) {
      final cap = _parseCapability(element, sourceFile);
      if (cap != null) capabilities.add(cap);

      final dto = _parseDto(element, sourceFile);
      if (dto != null) {
        dtos.add(dto);
        dtoNames.add(dto.className);
      }
    }

    _markNestedDtos(dtos, dtoNames);
    return CapabilityParseResult(capabilities: capabilities, dtos: dtos);
  }

  void _markNestedDtos(
    List<CapabilityDtoInfo> dtos,
    Set<String> dtoNames,
  ) {
    for (final dto in dtos) {
      for (var i = 0; i < dto.fields.length; i++) {
        final f = dto.fields[i];
        if (dtoNames.contains(f.typeName)) {
          dto.fields[i] = CapabilityDtoField(
            name: f.name,
            typeName: f.typeName,
            isNullable: f.isNullable,
            isRequired: f.isRequired,
            isList: f.isList,
            listElementType: f.listElementType,
            isMap: f.isMap,
            isDto: true,
            dtoClassName: f.typeName,
          );
        } else if (f.isList &&
            f.listElementType != null &&
            dtoNames.contains(f.listElementType)) {
          dto.fields[i] = CapabilityDtoField(
            name: f.name,
            typeName: f.typeName,
            isNullable: f.isNullable,
            isRequired: f.isRequired,
            isList: true,
            listElementType: f.listElementType,
            isMap: false,
            isDto: true,
            dtoClassName: f.listElementType,
          );
        }
      }
    }
  }

  CapabilityInfo? _parseCapability(ClassElement element, String sourceFile) {
    String? capabilityId;
    for (final annotation in element.metadata.annotations) {
      final constant = annotation.computeConstantValue();
      final typeName = constant?.type?.getDisplayString();
      if (typeName == 'LuaCapability') {
        capabilityId = constant?.getField('id')?.toStringValue();
        // Positional: first field of the annotation object.
        if (capabilityId == null) {
          // analyzer may store positional as field `id` from constructor.
          final fields = constant?.type?.element;
          capabilityId = constant?.getField('id')?.toStringValue();
        }
        break;
      }
    }
    if (capabilityId == null || capabilityId.isEmpty) {
      // Fallback: read from annotation AST-less reconstruction via toString
      for (final annotation in element.metadata.annotations) {
        final name = annotation.element?.displayName;
        if (name == 'LuaCapability' ||
            annotation.element?.enclosingElement?.name == 'LuaCapability') {
          final c = annotation.computeConstantValue();
          capabilityId = c?.getField('id')?.toStringValue();
        }
      }
    }
    if (capabilityId == null || capabilityId.isEmpty) return null;

    final methods = <CapabilityMethodInfo>[];
    for (final method in element.methods) {
      if (method.isStatic || method.isPrivate) continue;
      if (method.name == null) continue;
      // Skip synthetic / operators
      if (method.name!.startsWith('operator')) continue;

      var dispatchName = _snakeCase(method.name!);
      for (final annotation in method.metadata.annotations) {
        final constant = annotation.computeConstantValue();
        final typeName = constant?.type?.getDisplayString();
        if (typeName == 'LuaCapabilityMethod') {
          dispatchName =
              constant?.getField('name')?.toStringValue() ?? dispatchName;
        }
      }

      final returnType = method.returnType;
      String resultTypeName = 'Map';
      if (returnType is InterfaceType && returnType.element.name == 'Future') {
        if (returnType.typeArguments.isNotEmpty) {
          resultTypeName = _typeName(returnType.typeArguments.first);
        }
      } else {
        resultTypeName = _typeName(returnType);
      }

      String? argsType;
      var argsOptional = true;
      if (method.formalParameters.isNotEmpty) {
        final p0 = method.formalParameters.first;
        argsType = _typeName(p0.type);
        argsOptional = p0.isOptional ||
            p0.type.nullabilitySuffix == NullabilitySuffix.question;
      }

      methods.add(
        CapabilityMethodInfo(
          dartName: method.name!,
          dispatchName: dispatchName,
          returnType: resultTypeName,
          argsType: argsType,
          argsOptional: argsOptional,
        ),
      );
    }

    final className = element.name ?? 'Capability';
    return CapabilityInfo(
      className: className,
      capabilityId: capabilityId,
      sourceFile: sourceFile,
      methods: methods,
      implClassName: '_${className}Impl',
    );
  }

  CapabilityDtoInfo? _parseDto(ClassElement element, String sourceFile) {
    String? luauName;
    var found = false;
    for (final annotation in element.metadata.annotations) {
      final constant = annotation.computeConstantValue();
      final typeName = constant?.type?.getDisplayString();
      if (typeName == 'LuaCapabilityDto') {
        found = true;
        luauName = constant?.getField('name')?.toStringValue();
        break;
      }
    }
    if (!found) return null;

    final className = element.name ?? 'Dto';
    final fields = <CapabilityDtoField>[];
    for (final field in element.fields) {
      final name = field.name;
      if (name == null || name.startsWith('_') || field.isStatic) continue;

      final type = field.type;
      final nullable = type.nullabilitySuffix == NullabilitySuffix.question;
      final required = !nullable;

      var isList = false;
      String? listElement;
      var isMap = false;
      var typeName = _typeName(type);

      if (type is InterfaceType) {
        if (type.element.name == 'List' && type.typeArguments.isNotEmpty) {
          isList = true;
          listElement = _typeName(type.typeArguments.first);
          typeName = 'List<$listElement${type.typeArguments.first.nullabilitySuffix == NullabilitySuffix.question ? '?' : ''}>';
        } else if (type.element.name == 'Map') {
          isMap = true;
          typeName = 'Map<String, dynamic>';
        }
      }

      fields.add(
        CapabilityDtoField(
          name: name,
          typeName: typeName,
          isNullable: nullable,
          isRequired: required,
          isList: isList,
          listElementType: listElement,
          isMap: isMap,
        ),
      );
    }

    return CapabilityDtoInfo(
      className: className,
      luauName: luauName ?? className,
      sourceFile: sourceFile,
      fields: fields,
    );
  }

  String _typeName(DartType type) {
    if (type is InterfaceType) {
      final name = type.element.name ?? 'dynamic';
      if (type.typeArguments.isEmpty) return name;
      if (name == 'Future' && type.typeArguments.length == 1) {
        return _typeName(type.typeArguments.first);
      }
      return name;
    }
    return type.getDisplayString();
  }

  String _snakeCase(String camel) {
    final buf = StringBuffer();
    for (var i = 0; i < camel.length; i++) {
      final ch = camel[i];
      if (ch.toUpperCase() == ch && ch.toLowerCase() != ch) {
        if (i > 0) buf.write('_');
        buf.write(ch.toLowerCase());
      } else {
        buf.write(ch);
      }
    }
    return buf.toString();
  }
}
