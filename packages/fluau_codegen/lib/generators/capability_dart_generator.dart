/// Emits capability client + DTO fromJson/toJson into a part file.

import '../models/capability_info.dart';

class CapabilityDartGenerator {
  /// Emit a standalone `part of` file for the CLI.
  String generatePart({
    required CapabilityParseResult result,
    required String partOfLibrary,
  }) {
    final buf = StringBuffer();
    buf.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buf.writeln(
      '// ignore_for_file: require_trailing_commas, unnecessary_cast, unused_element',
    );
    buf.writeln();
    buf.writeln("part of '$partOfLibrary';");
    buf.writeln();
    buf.write(generatePartBody(result));
    return buf.toString();
  }

  /// Body of the generated part (without the `part of` header).
  String generatePartBody(CapabilityParseResult result) {
    if (result.capabilities.isEmpty && result.dtos.isEmpty) {
      return '';
    }
    final buf = StringBuffer();
    buf.writeln(
      '// ignore_for_file: require_trailing_commas, unnecessary_cast, unused_element',
    );
    buf.writeln();

    for (final dto in result.dtos) {
      buf.write(_generateDtoSerde(dto));
      buf.writeln();
    }

    for (final cap in result.capabilities) {
      buf.write(_generateClient(cap, result.dtos));
      buf.writeln();
    }

    return buf.toString();
  }

  String _generateDtoSerde(CapabilityDtoInfo dto) {
    final name = dto.className;
    final buf = StringBuffer();

    buf.writeln('$name _\$${name}FromJson(Map<String, dynamic> json) {');
    buf.writeln("  final map = CapabilityJson.asMap(json, context: '$name');");
    if (dto.fields.isEmpty) {
      buf.writeln('  // Touch map so invalid JSON still fails via asMap above.');
      buf.writeln('  if (map.isNotEmpty) { /* allow extra keys */ }');
      buf.writeln('  return const $name();');
    } else {
      buf.writeln('  try {');
      buf.writeln('    return $name(');
      for (final f in dto.fields) {
        buf.writeln('      ${f.name}: ${_decodeField(f)},');
      }
      buf.writeln('    );');
      buf.writeln('  } on CapabilityDecodeException {');
      buf.writeln('    rethrow;');
      buf.writeln('  } catch (e) {');
      buf.writeln(
        "    throw CapabilityDecodeException('$name.fromJson failed', cause: e, raw: json);",
      );
      buf.writeln('  }');
    }
    buf.writeln('}');
    buf.writeln();

    buf.writeln('Map<String, dynamic> _\$${name}ToJson($name instance) {');
    if (dto.fields.isEmpty) {
      buf.writeln('  return const <String, dynamic>{};');
    } else {
      buf.writeln('  return <String, dynamic>{');
      for (final f in dto.fields) {
        buf.writeln("    '${f.name}': ${_encodeField(f)},");
      }
      buf.writeln('  };');
    }
    buf.writeln('}');

    return buf.toString();
  }

  String _decodeField(CapabilityDtoField f) {
    if (f.isMap) {
      if (f.isNullable) {
        return "map['${f.name}'] == null ? null : "
            "CapabilityJson.asMap(map['${f.name}'], context: '${f.name}')";
      }
      return "CapabilityJson.asMap(map['${f.name}'], context: '${f.name}')";
    }
    if (f.isList) {
      final el = f.listElementType ?? 'dynamic';
      final mapEl = f.isDto
          ? '(e) => _\$${f.dtoClassName}FromJson('
              "CapabilityJson.asMap(e, context: '${f.name}[]'))"
          : '(e) => e as $el';
      if (f.isNullable) {
        return "map['${f.name}'] == null ? null : "
            "(map['${f.name}'] as List).map($mapEl).toList()";
      }
      return "(map['${f.name}'] as List).map($mapEl).toList()";
    }
    if (f.isDto) {
      final dto = f.dtoClassName ?? f.typeName;
      if (f.isNullable) {
        return "map['${f.name}'] == null ? null : _\$${dto}FromJson("
            "CapabilityJson.asMap(map['${f.name}'], context: '${f.name}'))";
      }
      return "_\$${dto}FromJson("
          "CapabilityJson.asMap(map['${f.name}'], context: '${f.name}'))";
    }

    final dartType = f.typeName.replaceAll('?', '');
    if (dartType == 'int') {
      return f.isNullable
          ? "CapabilityJson.optionalInt(map, '${f.name}')"
          : "CapabilityJson.requireInt(map, '${f.name}', context: '${f.name}')";
    }
    if (dartType == 'double' || dartType == 'num') {
      return f.isNullable
          ? "CapabilityJson.optionalDouble(map, '${f.name}')"
          : "CapabilityJson.requireDouble(map, '${f.name}', context: '${f.name}')";
    }
    if (f.isNullable) {
      return "CapabilityJson.optionalField<$dartType>(map, '${f.name}')";
    }
    return "CapabilityJson.requireField<$dartType>("
        "map, '${f.name}', context: '${f.name}')";
  }

  String _encodeField(CapabilityDtoField f) {
    final access = 'instance.${f.name}';
    if (f.isDto && f.isList) {
      final dto = f.dtoClassName ?? f.listElementType ?? f.typeName;
      return f.isNullable
          ? '$access?.map((e) => _\$${dto}ToJson(e)).toList()'
          : '$access.map((e) => _\$${dto}ToJson(e)).toList()';
    }
    if (f.isDto) {
      final dto = f.dtoClassName ?? f.typeName;
      return f.isNullable
          ? '$access == null ? null : _\$${dto}ToJson($access!)'
          : '_\$${dto}ToJson($access)';
    }
    return access;
  }

  String _generateClient(
    CapabilityInfo cap,
    List<CapabilityDtoInfo> dtos,
  ) {
    final dtoNames = dtos.map((d) => d.className).toSet();
    final buf = StringBuffer();
    final impl = cap.implClassName;

    buf.writeln('class $impl implements ${cap.className} {');
    buf.writeln('  $impl(this.pluginId);');
    buf.writeln();
    buf.writeln('  @override');
    buf.writeln('  final String pluginId;');
    buf.writeln();
    buf.writeln("  static const capabilityId = '${cap.capabilityId}';");
    buf.writeln();
    buf.writeln('  @override');
    buf.writeln('  bool get isCapable =>');
    buf.writeln(
      '      LuaPluginBridge.instance.pluginHasCapability(pluginId, capabilityId);',
    );
    buf.writeln();

    for (final m in cap.methods) {
      buf.writeln('  @override');
      if (m.argsType != null) {
        final bare = m.argsType!.replaceAll('?', '');
        final argsParam = m.argsOptional ? '[$bare? args]' : '$bare args';
        buf.writeln(
          '  Future<${m.returnType}> ${m.dartName}($argsParam) async {',
        );
        if (dtoNames.contains(bare)) {
          buf.writeln(
            '    final argsJson = jsonEncode('
            '_\$${bare}ToJson(args ?? const $bare()));',
          );
        } else {
          buf.writeln(
            "    final argsJson = jsonEncode(args ?? const <String, dynamic>{});",
          );
        }
      } else {
        buf.writeln('  Future<${m.returnType}> ${m.dartName}() async {');
        buf.writeln("    const argsJson = '{}';");
      }

      buf.writeln('    final raw = await LuaPluginBridge.instance.callPlugin(');
      buf.writeln('      pluginId: pluginId,');
      buf.writeln("      method: '${m.dispatchName}',");
      buf.writeln('      argsJson: argsJson,');
      buf.writeln('    );');
      buf.writeln('    try {');
      buf.writeln('      final decoded = jsonDecode(raw);');
      if (dtoNames.contains(m.returnType)) {
        buf.writeln(
          '      return _\$${m.returnType}FromJson('
          "CapabilityJson.asMap(decoded, context: '${m.returnType}'));",
        );
      } else if (m.returnType == 'String') {
        buf.writeln('      return decoded as String;');
      } else {
        buf.writeln(
          '      return CapabilityJson.asMap('
          "decoded, context: '${m.dartName}');",
        );
      }
      buf.writeln('    } on CapabilityDecodeException {');
      buf.writeln('      rethrow;');
      buf.writeln('    } catch (e) {');
      buf.writeln(
        "      throw CapabilityDecodeException("
        "'${cap.className}.${m.dartName} decode failed', cause: e, raw: raw);",
      );
      buf.writeln('    }');
      buf.writeln('  }');
      buf.writeln();
    }

    buf.writeln('}');
    return buf.toString();
  }
}
