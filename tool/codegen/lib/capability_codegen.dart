/// Capability-only codegen entry (`--generate-capabilities`).

library;

import 'dart:io';

import 'package:path/path.dart' as path;

import 'generators/capability_dart_generator.dart';
import 'generators/capability_luau_generator.dart';
import 'models/capability_info.dart';
import 'parsers/capability_parser.dart';

Future<void> runCapabilityCodegen(List<String> args) async {
  String? inputDir;
  String? luauOut;

  for (var i = 0; i < args.length; i++) {
    final flag = args[i];
    if (flag == '--generate-capabilities') continue;
    if (i + 1 >= args.length) {
      throw ArgumentError('Missing value for $flag');
    }
    final value = args[++i];
    switch (flag) {
      case '--input':
        inputDir = value;
        break;
      case '--luau-out':
        luauOut = value;
        break;
      default:
        throw ArgumentError('Unknown flag: $flag');
    }
  }

  if (inputDir == null) {
    throw ArgumentError(
      'Usage: --generate-capabilities --input <dir> [--luau-out <dir>]',
    );
  }

  final absoluteInput = path.normalize(path.absolute(inputDir));
  final absoluteLuau = path.normalize(
    path.absolute(luauOut ?? path.join(absoluteInput, '../assets/plugins/_types')),
  );

  print('Capability Code Generator');
  print('Input: $absoluteInput');
  print('Luau:  $absoluteLuau');
  print('');

  final parser = CapabilityParser();
  final result = await parser.parseDirectory(absoluteInput);

  print('Found ${result.capabilities.length} capabilities, '
      '${result.dtos.length} DTOs');
  for (final c in result.capabilities) {
    print('  - ${c.className} (${c.capabilityId})');
  }
  for (final d in result.dtos) {
    print('  - DTO ${d.className}');
  }
  print('');

  if (result.capabilities.isEmpty && result.dtos.isEmpty) {
    print('Nothing to generate.');
    return;
  }

  // Group by source file → one .g.dart part per library file.
  final byFile = <String, CapabilityParseResult>{};
  for (final cap in result.capabilities) {
    final entry = byFile.putIfAbsent(
      cap.sourceFile,
      () => CapabilityParseResult(capabilities: [], dtos: []),
    );
    entry.capabilities.add(cap);
  }
  for (final dto in result.dtos) {
    final entry = byFile.putIfAbsent(
      dto.sourceFile,
      () => CapabilityParseResult(capabilities: [], dtos: []),
    );
    // Avoid duplicating DTOs when multiple caps share a file.
    if (!entry.dtos.any((d) => d.className == dto.className)) {
      entry.dtos.add(dto);
    }
  }

  // Attach all DTOs referenced from a file's capabilities (same-file only for v1).
  final dartGen = CapabilityDartGenerator();
  for (final entry in byFile.entries) {
    final sourceFile = entry.key;
    final slice = entry.value;
    // Include every DTO that lives in this same source file.
    final fileDtos = result.dtos.where((d) => d.sourceFile == sourceFile).toList();
    final merged = CapabilityParseResult(
      capabilities: slice.capabilities,
      dtos: fileDtos.isNotEmpty ? fileDtos : slice.dtos,
    );

    final partOf = path.basename(sourceFile);
    final partPath = sourceFile.replaceFirst(RegExp(r'\.dart$'), '.g.dart');
    final code = dartGen.generatePart(
      result: merged,
      partOfLibrary: partOf,
    );
    await File(partPath).writeAsString(code);
    print('  Written: $partPath');
  }

  await Directory(absoluteLuau).create(recursive: true);
  final luauCode = CapabilityLuauGenerator().generate(result);
  final luauFile = File(path.join(absoluteLuau, 'capabilities.d.luau'));
  await luauFile.writeAsString(luauCode);
  print('  Written: ${luauFile.path}');
  print('');
  print('Capability codegen complete.');
}
