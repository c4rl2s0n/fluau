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
  print('Writes: widget_serializers.g.dart, lua_engine.rs, api/lua.rs,');
  print('ui.d.luau, capability *.g.dart parts, capabilities.d.luau.');
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

  _CliArgs({
    required this.mode,
    this.capabilitiesInput,
    this.widgetsInput,
    this.rustOut,
    this.dartOut,
    this.luauOut,
    this.deprecatedAlias,
    this.configPathUsed,
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

    switch (resolvedMode) {
      case _Mode.capabilities:
        return _CliArgs(
          mode: resolvedMode,
          capabilitiesInput: capsInput,
          luauOut: resolvedLuau,
          deprecatedAlias: deprecatedAlias,
          configPathUsed: fromYaml.configPathUsed,
        );
      case _Mode.widgets:
        return _CliArgs(
          mode: resolvedMode,
          widgetsInput: widgetsDir,
          rustOut: resolvedRust,
          dartOut: path.normalize(
            path.absolute(dartOut ?? widgetsDir),
          ),
          luauOut: resolvedLuau,
          deprecatedAlias: deprecatedAlias,
          configPathUsed: fromYaml.configPathUsed,
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
}) async {
  final absoluteInputDir = path.normalize(path.absolute(inputDir));
  final absoluteRust = path.normalize(path.absolute(rustOutputDir));
  final absoluteDart = path.normalize(path.absolute(dartOutputDir));
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
  print('Dart output: $absoluteDart');
  print('Luau output: $absoluteLuau');
  print('');

  print('Analyzing Dart files...');
  final parser = AnnotationParser();
  final classes = await parser.parseDirectory(absoluteInputDir);

  print('Found ${classes.length} Lua classes:');
  for (final luaClass in classes) {
    print(
      '  - ${luaClass.dartClassName} '
      '(${luaClass.isWidget ? 'widget' : 'data class'}) '
      '-> Lua: ${luaClass.luaName}',
    );
  }
  print('');

  if (classes.isEmpty) {
    print(
      'No Lua classes found. Make sure your classes have '
      '@LuaWidget or @LuaData annotations.',
    );
    return;
  }

  print('Generating Rust code...');
  final rustGenerator = RustGenerator();
  final rustCode = rustGenerator.generateModule(classes);

  await Directory(absoluteRust).create(recursive: true);
  final rustFile = File(path.join(absoluteRust, 'lua_engine.rs'));
  await rustFile.writeAsString(rustCode);
  print('  Written: ${rustFile.path}');

  final apiCode = _generateApiBindings();
  final apiDir = Directory(path.join(absoluteRust, 'api'));
  await apiDir.create(recursive: true);
  final apiFile = File(path.join(apiDir.path, 'lua.rs'));
  await apiFile.writeAsString(apiCode);
  print('  Written: ${apiFile.path}');

  print('Generating Dart code...');
  final dartGenerator = DartSerializerGenerator();
  final dartCode = dartGenerator.generateAll(classes);

  await Directory(absoluteDart).create(recursive: true);
  final dartFile = File(path.join(absoluteDart, 'widget_serializers.g.dart'));
  await dartFile.writeAsString(dartCode);
  print('  Written: ${dartFile.path}');

  print('Generating Luau stubs...');
  final luauGenerator = LuauStubGenerator();
  final luauCode = luauGenerator.generate(classes);

  await Directory(absoluteLuau).create(recursive: true);
  final luauFile = File(path.join(absoluteLuau, 'ui.d.luau'));
  await luauFile.writeAsString(luauCode);
  print('  Written: ${luauFile.path}');

  print('');
  print('Widget codegen complete!');
}

String _generateApiBindings() {
  return '''
// Generated API bindings for Lua plugin
// DO NOT EDIT - This file is automatically generated
//
// Persistent session APIs live in api/plugin.rs (not overwritten here).

use crate::lua_engine;

/// Initialization function for flutter_rust_bridge
#[flutter_rust_bridge::frb(init)]
pub fn init_lua() {
    // Any initialization needed for the Lua API
}

/// Execute a one-shot Lua script that returns a widget tree (legacy helper).
#[flutter_rust_bridge::frb(sync)]
pub fn run_lua_ui_script(script: String) -> Result<String, String> {
    lua_engine::execute_ui_script(&script)
}

/// Get a state value by key (legacy global state map).
#[flutter_rust_bridge::frb(sync)]
pub fn get_lua_state(key: String) -> Result<String, String> {
    crate::state::get_state(&key)
}

/// Set a state value (legacy global state map).
#[flutter_rust_bridge::frb(sync)]
pub fn set_lua_state(key: String, value: String) -> Result<(), String> {
    crate::state::set_state(key, value)
}

/// Get all state as JSON string (legacy global state map).
#[flutter_rust_bridge::frb(sync)]
pub fn get_all_lua_state() -> Result<String, String> {
    crate::state::get_all_state()
}
''';
}
