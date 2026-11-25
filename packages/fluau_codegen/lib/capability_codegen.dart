/// Capability codegen (`--capabilities` / default generate-all).

library;

import 'dart:io';

import 'package:path/path.dart' as path;

import 'generators/capability_dart_generator.dart';
import 'generators/capability_luau_generator.dart';
import 'models/capability_info.dart';
import 'parsers/capability_parser.dart';

/// Generate capability Dart `*.g.dart` parts and `capabilities.d.luau`.
Future<void> generateCapabilities({
  required String inputDir,
  String? luauOut,
}) async {
  final absoluteInput = path.normalize(path.absolute(inputDir));
  final absoluteLuau = path.normalize(
    path.absolute(
      luauOut ?? path.join(absoluteInput, '../assets/plugins/_types'),
    ),
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
    print('Nothing to generate for capabilities.');
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
    if (!entry.dtos.any((d) => d.className == dto.className)) {
      entry.dtos.add(dto);
    }
  }

  final dartGen = CapabilityDartGenerator();
  for (final entry in byFile.entries) {
    final sourceFile = entry.key;
    final slice = entry.value;
    final fileDtos =
        result.dtos.where((d) => d.sourceFile == sourceFile).toList();
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
