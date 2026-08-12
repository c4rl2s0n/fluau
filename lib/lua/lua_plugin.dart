import 'dart:convert';
import 'package:flutter/material.dart';
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
  /// 1. Set any initial state if provided
  /// 2. Execute the Lua script through the Rust FFI
  /// 3. Return the JSON string representing the widget tree
  Future<String> _executeLuaScript(BuildContext context) async {
    // TODO: Set initial state through Rust FFI
    // if (initialState != null) {
    //   for (final entry in initialState!.entries) {
    //     await RustLib.instance.api.setLuaState(
    //       key: entry.key,
    //       value: jsonEncode(entry.value),
    //     );
    //   }
    // }
    
    // TODO: Call the actual Rust function
    // For now, return a mock response for testing
    // return RustLib.instance.api.runLuaUiScript(script: luaScript);
    
    // Mock response for testing without Rust FFI
    return _mockExecuteScript(luaScript);
  }
  
  /// Mock script execution for testing without Rust FFI
  ///
  /// This is a temporary method that will be replaced by actual FFI calls.
  String _mockExecuteScript(String script) {
    // Simple mock: if the script contains "Text", return a Text widget JSON
    if (script.contains('Text') || script.contains('text')) {
      return jsonEncode({
        'type': 'Text',
        'text': 'Hello from Lua!',
        'size': 'large',
        'color': 'primary',
        'weight': 'bold',
      });
    }
    
    // If the script contains "Column", return a Column widget JSON
    if (script.contains('Column') || script.contains('column')) {
      return jsonEncode({
        'type': 'Column',
        'spacing': 16.0,
        'mainAxisAlignment': 'center',
        'crossAxisAlignment': 'center',
        'children': [
          {
            'type': 'Text',
            'text': 'First Item',
          },
          {
            'type': 'Text',
            'text': 'Second Item',
          },
        ],
      });
    }
    
    // Default: return an empty widget
    return jsonEncode({'type': 'SizedBox'});
  }
}
