import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import '../generators/capability_dart_generator.dart';
import '../parsers/capability_parser.dart';

/// Scans a library for `@LuaCapability` / `@LuaCapabilityDto` and emits the
/// part body (client + top-level serde).
class CapabilityGenerator extends Generator {
  @override
  Future<String?> generate(LibraryReader library, BuildStep buildStep) async {
    final LibraryElement element = library.element;
    final parsed = CapabilityParser().parseLibrary(
      element,
      sourceFile: buildStep.inputId.path,
    );
    if (parsed.capabilities.isEmpty && parsed.dtos.isEmpty) {
      return null;
    }
    final body = CapabilityDartGenerator().generatePartBody(parsed);
    if (body.trim().isEmpty) return null;
    return body;
  }
}
