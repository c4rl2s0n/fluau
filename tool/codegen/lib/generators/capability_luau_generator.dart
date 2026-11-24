/// Emits Luau stubs for capability dispatch methods and DTO table shapes.

import '../models/capability_info.dart';

class CapabilityLuauGenerator {
  String generate(CapabilityParseResult result) {
    final buf = StringBuffer();
    buf.writeln('-- GENERATED capability stubs (LSP / docs only).');
    buf.writeln('-- Do NOT treat this as a runnable dispatch implementation.');
    buf.writeln('-- Plugin packages must hand-write dispatch(method, args).');
    buf.writeln();

    for (final dto in result.dtos) {
      buf.writeln('-- DTO: ${dto.luauName}');
      buf.writeln('export type ${dto.luauName} = {');
      for (final f in dto.fields) {
        final ty = _luauType(f);
        final opt = f.isNullable || !f.isRequired ? '?' : '';
        buf.writeln('  ${f.name}: $ty$opt,');
      }
      buf.writeln('}');
      buf.writeln();
    }

    for (final cap in result.capabilities) {
      buf.writeln('-- Capability: ${cap.capabilityId} (${cap.className})');
      buf.writeln('-- Advertise in plugin.yaml: capabilities: ["${cap.capabilityId}"]');
      buf.writeln();
      for (final m in cap.methods) {
        final argsTy = m.argsType ?? '{}';
        buf.writeln('-- dispatch("${m.dispatchName}", args) -> ${m.returnType}');
        buf.writeln(
          '-- function dispatch_${m.dispatchName}(args: $argsTy): ${m.returnType}',
        );
      }
      buf.writeln();
      buf.writeln('-- Combined dispatch shape (illustrative):');
      buf.writeln('export type ${cap.className}Dispatch = {');
      for (final m in cap.methods) {
        final argsTy = m.argsType ?? '{}';
        buf.writeln(
          '  -- ["${m.dispatchName}"]: ($argsTy) -> ${m.returnType}',
        );
      }
      buf.writeln('}');
      buf.writeln();
    }

    return buf.toString();
  }

  String _luauType(CapabilityDtoField f) {
    if (f.isMap) return '{ [string]: any }';
    if (f.isList) {
      final el = f.listElementType ?? 'any';
      return '{ $el }';
    }
    if (f.isDto) return f.dtoClassName ?? f.typeName;
    switch (f.typeName.replaceAll('?', '')) {
      case 'String':
        return 'string';
      case 'int':
      case 'double':
      case 'num':
        return 'number';
      case 'bool':
        return 'boolean';
      default:
        return f.typeName.replaceAll('?', '');
    }
  }
}
