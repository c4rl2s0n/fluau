/// Lua Plugin Code Generator
///
/// Main entry point for the code generation CLI.
/// This tool parses Dart files with LuaWidget/LuaData annotations
/// and generates Rust and Dart code for the Lua plugin framework.

library lua_plugin_codegen;

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:path/path.dart' as path;

import 'parsers/annotation_parser.dart';
import 'generators/rust_generator.dart';
import 'generators/dart_serializer_generator.dart';

/// Main entry point for the code generator CLI
void main(List<String> args) async {
  if (args.isEmpty || args[0] != '--generate') {
    _printUsage();
    exit(1);
  }
  
  try {
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
  print('    --dart-out <dart_directory>');
  print('');
  print('Arguments:');
  print('  --input     Directory containing Dart files with LuaWidget annotations');
  print('  --rust-out  Directory to write generated Rust files');
  print('  --dart-out  Directory to write generated Dart files');
  print('');
  print('Example:');
  print('  flutter pub run lua_plugin_codegen --generate \\');
  print('    --input lib/lua/widgets \\');
  print('    --rust-out rust/src \\');
  print('    --dart-out lib/lua/widgets');
}

/// CLI for the code generator
class LuaCodegenCli {
  final String inputDir;
  final String rustOutputDir;
  final String dartOutputDir;
  
  LuaCodegenCli({
    required this.inputDir,
    required this.rustOutputDir,
    required this.dartOutputDir,
  });
  
  /// Create from command-line arguments
  factory LuaCodegenCli.fromArgs(List<String> args) {
    if (args.length < 4) {
      throw ArgumentError('Missing arguments. Expected: --generate --input <dir> --rust-out <dir> --dart-out <dir>');
    }
    
    // Parse arguments: --generate --input <input> --rust-out <rust> --dart-out <dart>
    String? inputDir;
    String? rustOut;
    String? dartOut;
    
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
    print('');
    
    // Create analysis context
    print('Analyzing Dart files...');
    final absoluteInputDir = path.absolute(inputDir);
    final context = AnalysisContextCollection(includedPaths: [absoluteInputDir]);
    
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
    
    print('');
    print('Code generation complete!');
    print('');
    print('Next steps:');
    print('  1. Update Rust Cargo.toml if needed');
    print('  2. Update Rust lib.rs to export lua_engine module');
    print('  3. Run `cargo check` to verify Rust code');
    print('  4. Run `flutter pub get` to update Dart dependencies');
  }
  
  /// Generate the Rust API bindings
  String _generateApiBindings() {
    return '''
// Generated API bindings for Lua plugin
// DO NOT EDIT - This file is automatically generated

use crate::lua_engine;

/// Execute a Lua script that returns a widget tree
/// Returns JSON string representing the widget
#[flutter_rust_bridge::frb(sync)]
pub fn run_lua_ui_script(script: String) -> Result<String, String> {
    lua_engine::execute_ui_script(&script)
}

/// Get a state value by key
#[flutter_rust_bridge::frb(sync)]
pub fn get_lua_state(key: String) -> Result<String, String> {
    crate::state::get_state(&key)
}

/// Set a state value
#[flutter_rust_bridge::frb(sync)]
pub fn set_lua_state(key: String, value: String) -> Result<(), String> {
    crate::state::set_state(key, value)
}

/// Get all state as JSON string
#[flutter_rust_bridge::frb(sync)]
pub fn get_all_lua_state() -> Result<String, String> {
    crate::state::get_all_state()
}

/// Execute a Lua callback by ID
#[flutter_rust_bridge::frb(sync)]
pub fn execute_lua_callback(callback_id: String) -> Result<String, String> {
    use mlua::Lua;
    let lua = Lua::new();
    crate::callbacks::CALLBACKS.execute(&lua, &callback_id)
        .map(|v| v.to_string())
        .map_err(|e| e.to_string())
}
''';
  }
}
