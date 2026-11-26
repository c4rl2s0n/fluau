/// fluau Code Generator CLI.
///
/// Default: generate widgets + capabilities.
/// Paths: CLI flags > fluau.yaml > built-in defaults.
/// Selective: `--widgets` or `--capabilities`.
/// Deprecated aliases: `--generate`, `--generate-capabilities`.

library fluau_codegen;

import 'dart:io';

import 'package:path/path.dart' as path;

import 'capability_codegen.dart';
import 'fluau_config.dart';
import 'generators/dart_serializer_generator.dart';
import 'generators/luau_stub_generator.dart';
import 'generators/rust_generator.dart';
import 'parsers/annotation_parser.dart';

enum _Mode { all, widgets, capabilities }

/// Main entry point for the code generator CLI.
void main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    exit(0);
  }

  try {
    final parsed = _CliArgs.parse(args);
    if (parsed.deprecatedAlias != null) {
      stderr.writeln(
        'warning: ${parsed.deprecatedAlias} is deprecated; '
        'use ${parsed.mode == _Mode.widgets ? '--widgets' : '--capabilities'} '
        '(or omit for generate-all).',
      );
    }
    if (parsed.configPathUsed != null) {
      print('Using config: ${parsed.configPathUsed}');
    } else {
      print('No fluau.yaml — using built-in path defaults.');
    }

    final doWidgets =
        parsed.mode == _Mode.all || parsed.mode == _Mode.widgets;
    final doCapabilities =
        parsed.mode == _Mode.all || parsed.mode == _Mode.capabilities;

    if (doWidgets) {
      await generateWidgets(
        inputDir: parsed.widgetsInput!,
        rustOutputDir: parsed.rustOut!,
        dartOutputDir: parsed.dartOut!,
        luauOutputDir: parsed.luauOut,
        packageRoot: parsed.packageRoot,
        packageName: parsed.packageName,
      );
    }
    if (doCapabilities) {
      await generateCapabilities(
        inputDir: parsed.capabilitiesInput!,
        luauOut: parsed.luauOut,
      );
    }
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace:');
    print(stackTrace);
    exit(1);
  }
}

void _printUsage() {
  print('fluau Code Generator');
  print('');
  print('From the Flutter app root (fluau.yaml optional):');
  print('  dart run fluau_codegen');
  print('  dart run fluau_codegen --widgets');
  print('  dart run fluau_codegen --capabilities');
  print('');
  print('Paths resolve as: CLI flags > fluau.yaml > built-in defaults.');
  print('  codegen.input / codegen.widgets / codegen.luau_out');
  print('  rust.crate_root → rust-out = <crate_root>/src');
  print('  stubs.ui_d_luau → luau_out parent when codegen.luau_out omitted');
  print('');
  print('Overrides:');
  print('  --config <fluau.yaml>');
  print('  --input <dir>  --widgets-input <dir>  --rust-out <dir>');
  print('  --dart-out <dir>  --luau-out <dir>');
  print('');
  print('Writes: widget_serializers.g.dart, lua_engine.rs,');
  print('ui.d.luau, capability *.g.dart parts, capabilities.d.luau.');
  print('Also ensures `pub mod lua_engine;` in lib.rs (lua_engine uses fluau::mlua / fluau::serde_json).');
}

class _CliArgs {
  final _Mode mode;
  final String? capabilitiesInput;
  final String? widgetsInput;
  final String? rustOut;
  final String? dartOut;
  final String? luauOut;
  final String? deprecatedAlias;
  final String? configPathUsed;
  final String packageRoot;
  final String? packageName;

  _CliArgs({
    required this.mode,
    this.capabilitiesInput,
    this.widgetsInput,
    this.rustOut,
    this.dartOut,
    this.luauOut,
    this.deprecatedAlias,
    this.configPathUsed,
    required this.packageRoot,
    this.packageName,
  });

  factory _CliArgs.parse(List<String> args) {
    _Mode? mode;
    String? deprecatedAlias;
    String? input;
    String? widgetsInput;
    String? rustOut;
    String? dartOut;
    String? luauOut;
    var configPath = 'fluau.yaml';

    for (var i = 0; i < args.length; i++) {
      final flag = args[i];
      switch (flag) {
        case '--widgets':
          mode = _Mode.widgets;
          continue;
        case '--capabilities':
          mode = _Mode.capabilities;
          continue;
        case '--generate':
          mode = _Mode.widgets;
          deprecatedAlias = '--generate';
          continue;
        case '--generate-capabilities':
          mode = _Mode.capabilities;
          deprecatedAlias = '--generate-capabilities';
          continue;
      }

      if (!flag.startsWith('--')) {
        throw ArgumentError('Unexpected argument: $flag');
      }
      if (i + 1 >= args.length) {
        throw ArgumentError('Missing value for $flag');
      }
      final value = args[++i];
      switch (flag) {
        case '--config':
          configPath = value;
          break;
        case '--input':
          input = value;
          break;
        case '--widgets-input':
          widgetsInput = value;
          break;
        case '--rust-out':
          rustOut = value;
          break;
        case '--dart-out':
          dartOut = value;
          break;
        case '--luau-out':
          luauOut = value;
          break;
        default:
          throw ArgumentError('Unknown flag: $flag');
      }
    }

    final fromYaml = loadCodegenPaths(configPath: configPath);
    final resolvedMode = mode ?? _Mode.all;

    // CLI overrides yaml/defaults.
    final capsInput = path.normalize(
      path.absolute(input ?? fromYaml.input),
    );
    final wInput = path.normalize(
      path.absolute(widgetsInput ?? fromYaml.widgets),
    );
    // --widgets with --input historically meant the widgets dir.
    final widgetsDir = resolvedMode == _Mode.widgets && input != null
        ? path.normalize(path.absolute(widgetsInput ?? input))
        : wInput;
    final resolvedRust = path.normalize(
      path.absolute(rustOut ?? fromYaml.rustOut),
    );
    final resolvedDart = path.normalize(
      path.absolute(dartOut ?? fromYaml.dartOut),
    );
    final resolvedLuau = path.normalize(
      path.absolute(luauOut ?? fromYaml.luauOut),
    );

    final packageRoot = path.normalize(path.absolute('.'));

    switch (resolvedMode) {
      case _Mode.capabilities:
        return _CliArgs(
          mode: resolvedMode,
          capabilitiesInput: capsInput,
          luauOut: resolvedLuau,
          deprecatedAlias: deprecatedAlias,
          configPathUsed: fromYaml.configPathUsed,
          packageRoot: packageRoot,
          packageName: fromYaml.packageName,
        );
      case _Mode.widgets:
        return _CliArgs(
          mode: resolvedMode,
          widgetsInput: widgetsDir,
          rustOut: resolvedRust,
          // Serializers go under lua_root (yaml dartOut), not next to widgets.
          dartOut: resolvedDart,
          luauOut: resolvedLuau,
          deprecatedAlias: deprecatedAlias,
          configPathUsed: fromYaml.configPathUsed,
          packageRoot: packageRoot,
          packageName: fromYaml.packageName,
        );
      case _Mode.all:
        return _CliArgs(
          mode: resolvedMode,
          capabilitiesInput: capsInput,
          widgetsInput: widgetsDir,
          rustOut: resolvedRust,
          dartOut: resolvedDart,
          luauOut: resolvedLuau,
          deprecatedAlias: deprecatedAlias,
          configPathUsed: fromYaml.configPathUsed,
          packageRoot: packageRoot,
          packageName: fromYaml.packageName,
        );
    }
  }
}

/// Generate widget serializers, Rust UI glue, and `ui.d.luau`.
Future<void> generateWidgets({
  required String inputDir,
  required String rustOutputDir,
  required String dartOutputDir,
  String? luauOutputDir,
  required String packageRoot,
  String? packageName,
}) async {
  final absoluteInputDir = path.normalize(path.absolute(inputDir));
  final absoluteRust = path.normalize(path.absolute(rustOutputDir));
  final absoluteDart = path.normalize(path.absolute(dartOutputDir));
  final absolutePackageRoot = path.normalize(path.absolute(packageRoot));
  final absoluteLuau = path.normalize(
    path.absolute(
      luauOutputDir ??
          path.join(absoluteInputDir, '../../assets/plugins/_types'),
    ),
  );

  print('fluau Widget Code Generator');
  print('===========================');
  print('');
  print('Input directory: $absoluteInputDir');
  print('Rust output: $absoluteRust');
  print('Dart output (lua_root): $absoluteDart');
  print('Luau output: $absoluteLuau');
  print('');

  print('Analyzing Dart files...');
  final parser = AnnotationParser();
  final parsed = await parser.parseDirectory(absoluteInputDir);
  final classes = parsed.classes;
  final enums = parsed.enums;

  print('Found ${classes.length} Lua classes:');
  for (final luaClass in classes) {
    print(
      '  - ${luaClass.dartClassName} '
      '(${luaClass.isWidget ? 'widget' : 'data class'}) '
      '-> Lua: ${luaClass.luaName}',
    );
  }
  if (enums.isNotEmpty) {
    print('Found ${enums.length} Lua enums:');
    for (final e in enums) {
      print('  - ${e.dartName} -> enums.${e.luaName}');
    }
  }
  print('');

  if (classes.isEmpty && enums.isEmpty) {
    print(
      'No Lua classes found. Make sure your classes have '
      '@LuaWidget or @LuaData annotations.',
    );
    return;
  }

  print('Generating Rust code...');
  final rustGenerator = RustGenerator();
  final rustCode = rustGenerator.generateModule(classes, enums: enums);

  await Directory(absoluteRust).create(recursive: true);
  final rustFile = File(path.join(absoluteRust, 'lua_engine.rs'));
  await rustFile.writeAsString(rustCode);
  print('  Written: ${rustFile.path}');

  await _ensureLibRsMod(absoluteRust);
  await _retireLegacyApiLua(absoluteRust);

  print('Generating Dart code...');
  await Directory(absoluteDart).create(recursive: true);
  final dartFile = File(path.join(absoluteDart, 'widget_serializers.g.dart'));
  final dartGenerator = DartSerializerGenerator();
  final dartCode = dartGenerator.generateAll(
    classes,
    outputFile: dartFile.path,
    packageRoot: absolutePackageRoot,
    packageName: packageName,
  );
  await dartFile.writeAsString(dartCode);
  print('  Written: ${dartFile.path}');

  print('Generating Luau stubs...');
  final luauGenerator = LuauStubGenerator();
  final luauCode = luauGenerator.generate(classes, enums: enums);

  await Directory(absoluteLuau).create(recursive: true);
  final luauFile = File(path.join(absoluteLuau, 'ui.d.luau'));
  await luauFile.writeAsString(luauCode);
  print('  Written: ${luauFile.path}');

  print('');
  print('Widget codegen complete!');
  print('');
  print('Next: call `crate::lua_engine::register_ui_catalog()` once from');
  print('your #[frb(init)] / process start (or pass setup_lua_api to fluau::setup).');
}

/// Ensure `pub mod lua_engine;` exists in the crate `lib.rs` next to rust-out.
Future<void> _ensureLibRsMod(String rustSrcDir) async {
  final libRs = File(path.join(rustSrcDir, 'lib.rs'));
  if (!await libRs.exists()) {
    print('  Skipped lib.rs mod: ${libRs.path} not found');
    return;
  }

  final content = await libRs.readAsString();
  if (RegExp(r'\bmod\s+lua_engine\s*;').hasMatch(content)) {
    print('  lib.rs already declares mod lua_engine');
    return;
  }

  // Insert after the first block of `mod` / `pub mod` lines, or at top.
  final modLine = 'pub mod lua_engine;';
  final lines = content.split('\n');
  var insertAt = 0;
  for (var i = 0; i < lines.length; i++) {
    final trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('mod ') ||
        trimmed.startsWith('pub mod ') ||
        trimmed.startsWith('pub use ') ||
        trimmed.isEmpty ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('#!')) {
      insertAt = i + 1;
      continue;
    }
    break;
  }
  lines.insert(insertAt, modLine);
  await libRs.writeAsString(lines.join('\n'));
  print('  Added `$modLine` to ${libRs.path}');
}

/// Stop regenerating orphan `api/lua.rs`. If present, replace with a pointer
/// stub and drop `mod lua` from `api/mod.rs` when that file only re-exports it.
Future<void> _retireLegacyApiLua(String rustSrcDir) async {
  final apiFile = File(path.join(rustSrcDir, 'api', 'lua.rs'));
  final apiMod = File(path.join(rustSrcDir, 'api', 'mod.rs'));

  if (await apiMod.exists()) {
    final modSrc = await apiMod.readAsString();
    final cleaned = modSrc
        .replaceAll(
          RegExp(r'^\s*pub\s+mod\s+lua\s*;\s*\n?', multiLine: true),
          '',
        )
        .replaceAll(
          RegExp(r'^\s*mod\s+lua\s*;\s*\n?', multiLine: true),
          '',
        );
    if (cleaned != modSrc) {
      await apiMod.writeAsString(cleaned);
      print('  Removed `mod lua` from ${apiMod.path}');
    }
  }

  if (!await apiFile.exists()) {
    return;
  }

  // Leave a tiny pointer file so grepping old paths still finds guidance.
  // Hosts that still need FRB wrappers should own them under a different name.
  const stub = '''
// Retired by fluau_codegen — do not `mod` this file.
//
// UI catalog: crate::lua_engine (codegen-owned).
// Call once from #[frb(init)] / process start:
//   let _ = crate::lua_engine::register_ui_catalog();
// Or pass ui_setup: Some(crate::lua_engine::setup_lua_api) to fluau::setup.
// Note: fluau::setup clears UI registration — call register_ui_catalog *after*
// setup when ui_setup is None, or pass ui_setup inside setup.
''';
  await apiFile.writeAsString(stub);
  print('  Retired legacy file: ${apiFile.path}');
}
