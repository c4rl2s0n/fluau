import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:luatest/src/rust/api/lua.dart';
import 'widgets/widget.dart';

/// Main widget that executes a Lua script and renders the resulting UI
///
/// This widget takes a Lua script as input, executes it through Rust,
/// and renders the widget tree that the Lua script returns.
///
/// Example usage:
/// ```dart
/// LuaPlugin(
///   luaScript: '''
///     return ui.Text {
///       text = "Hello from Lua!",
///       size = "large",
///       color = "primary",
///       weight = "bold"
///     }
///   ''',
/// )
/// ```
class LuaPlugin extends StatelessWidget {
  /// The Lua script to execute
  final String luaScript;
  
  /// Optional initial state to set before executing the script
  final Map<String, dynamic>? initialState;
  
  const LuaPlugin({
    super.key,
    required this.luaScript,
    this.initialState,
  });
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _executeLuaScript(context),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Lua Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Parse the JSON and build the widget
        try {
          final widgetMap = jsonDecode(snapshot.data!) as Map<String, dynamic>;
          return LuaWidgetRegistry.buildFromMap(context, widgetMap);
        } catch (e) {
          return Center(
            child: Text(
              'Parse Error: $e',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
      },
    );
  }
  
  /// Execute the Lua script and return the JSON result
  ///
  /// This method will:
  /// 1. Set any initial state if provided (TODO: not yet implemented)
  /// 2. Execute the Lua script through the Rust FFI
  /// 3. Return the JSON string representing the widget tree
  Future<String> _executeLuaScript(BuildContext context) async {
    // TODO: Set initial state through Rust FFI
    // if (initialState != null) {
    //   for (final entry in initialState!.entries) {
    //     await setLuaState(
    //       key: entry.key,
    //       value: jsonEncode(entry.value),
    //     );
    //   }
    // }
    
    // Call the actual Rust function
    return runLuaUiScript(script: luaScript);
  }
}
