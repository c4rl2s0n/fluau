/// Lua Plugin Code Generator
///
/// Main entry point for the code generation CLI.
/// This tool parses Dart files with LuaWidget/LuaData annotations
/// and generates Rust and Dart code for the Lua plugin framework.

library lua_plugin_codegen;

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'capability_codegen.dart' as capability_codegen;
import 'parsers/annotation_parser.dart';
import 'generators/rust_generator.dart';
import 'generators/dart_serializer_generator.dart';
import 'generators/luau_stub_generator.dart';

/// Main entry point for the code generator CLI
void main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    exit(1);
  }

  try {
    if (args[0] == '--generate-capabilities') {
      await capability_codegen.runCapabilityCodegen(args);
      return;
    }
    if (args[0] != '--generate') {
      _printUsage();
      exit(1);
    }
    final cli = LuaCodegenCli.fromArgs(args);
    await cli.run();
  } catch (e, stackTrace) {
    print('Error: $e');
    print('Stack trace:');
    print(stackTrace);
    exit(1);
  }
}

/// Print usage information
void _printUsage() {
  print('Lua Plugin Code Generator');
  print('');
  print('Usage:');
  print('  dart run lua_plugin_codegen --generate \\');
  print('    --input <dart_directory> \\');
  print('    --rust-out <rust_directory> \\');
  print('    --dart-out <dart_directory> \\');
  print('    [--luau-out <luau_directory>]');
  print('');
  print('  dart run lua_plugin_codegen --generate-capabilities \\');
  print('    --input <dart_directory> \\');
  print('    [--luau-out <luau_directory>]');
  print('');
  print('Widget mode writes lua_engine.rs + widget_serializers + ui.d.luau.');
  print('Capability mode writes *.g.dart parts + capabilities.d.luau.');
}

/// CLI for the code generator
class LuaCodegenCli {
  final String inputDir;
  final String rustOutputDir;
  final String dartOutputDir;
  final String luauOutputDir;
  
  LuaCodegenCli({
    required this.inputDir,
    required this.rustOutputDir,
    required this.dartOutputDir,
    required this.luauOutputDir,
  });
  
  /// Create from command-line arguments
  factory LuaCodegenCli.fromArgs(List<String> args) {
    if (args.length < 4) {
      throw ArgumentError(
        'Missing arguments. Expected: --generate --input <dir> '
        '--rust-out <dir> --dart-out <dir> [--luau-out <dir>]',
      );
    }
    
    // Parse arguments: --generate --input <input> --rust-out <rust> --dart-out <dart> [--luau-out <luau>]
    String? inputDir;
    String? rustOut;
    String? dartOut;
    String? luauOut;
    
    for (int i = 1; i < args.length; i += 2) {
      final flag = args[i];
      if (i + 1 >= args.length) {
        throw ArgumentError('Missing value for flag: $flag');
      }
      final value = args[i + 1];
      
      switch (flag) {
        case '--input':
          inputDir = value;
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
    
    if (inputDir == null || rustOut == null || dartOut == null) {
      throw ArgumentError('Missing required arguments');
    }
    
    return LuaCodegenCli(
      inputDir: inputDir,
      rustOutputDir: rustOut,
      dartOutputDir: dartOut,
      luauOutputDir: luauOut ?? '../../assets/plugins/_types',
    );
  }
  
  /// Run the code generation
  Future<void> run() async {
    print('Lua Plugin Code Generator');
    print('========================');
    print('');
    print('Input directory: $inputDir');
    print('Rust output: $rustOutputDir');
    print('Dart output: $dartOutputDir');
    print('Luau output: $luauOutputDir');
    print('');
    
    // Create analysis context
    print('Analyzing Dart files...');
    final absoluteInputDir = path.normalize(path.absolute(inputDir));
    
    // Parse all Dart files in the input directory
    final parser = AnnotationParser();
    final classes = await parser.parseDirectory(absoluteInputDir);
    
    print('Found ${classes.length} Lua classes:');
    for (final luaClass in classes) {
      print('  - ${luaClass.dartClassName} (${luaClass.isWidget ? 'widget' : 'data class'}) -> Lua: ${luaClass.luaName}');
    }
    print('');
    
    if (classes.isEmpty) {
      print('No Lua classes found. Make sure your classes have @LuaWidget or @LuaData annotations.');
      return;
    }
    
    // Generate Rust code
    print('Generating Rust code...');
    final rustGenerator = RustGenerator();
    final rustCode = rustGenerator.generateModule(classes);
    
    // Ensure output directory exists
    await Directory(rustOutputDir).create(recursive: true);
    
    // Write Rust file
    final rustFile = File(path.join(rustOutputDir, 'lua_engine.rs'));
    await rustFile.writeAsString(rustCode);
    print('  Written: ${rustFile.path}');
    
    // Generate API bindings
    final apiCode = _generateApiBindings();
    final apiDir = Directory(path.join(rustOutputDir, 'api'));
    await apiDir.create(recursive: true);
    final apiFile = File(path.join(apiDir.path, 'lua.rs'));
    await apiFile.writeAsString(apiCode);
    print('  Written: ${apiFile.path}');
    
    // Generate Dart code
    print('Generating Dart code...');
    final dartGenerator = DartSerializerGenerator();
    final dartCode = dartGenerator.generateAll(classes);
    
    // Ensure output directory exists
    await Directory(dartOutputDir).create(recursive: true);
    
    // Write Dart file
    final dartFile = File(path.join(dartOutputDir, 'widget_serializers.g.dart'));
    await dartFile.writeAsString(dartCode);
    print('  Written: ${dartFile.path}');

    // Generate Luau definition stubs
    print('Generating Luau stubs...');
    final luauGenerator = LuauStubGenerator();
    final luauCode = luauGenerator.generate(classes);

    await Directory(luauOutputDir).create(recursive: true);
    final luauFile = File(path.join(luauOutputDir, 'ui.d.luau'));
    await luauFile.writeAsString(luauCode);
    print('  Written: ${luauFile.path}');
    
    print('');
    print('Code generation complete!');
    print('');
    print('Next steps:');
    print('  1. Update Rust Cargo.toml if needed');
    print('  2. Update Rust lib.rs to export lua_engine module');
    print('  3. Run `cargo check` to verify Rust code');
    print('  4. Run `flutter pub get` to update Dart dependencies');
    print('  5. Point luau-lsp at assets/plugins/_types via .luaurc');
  }
  
  /// Generate legacy one-shot Lua API bindings (session API lives in api/plugin.rs).
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
}
