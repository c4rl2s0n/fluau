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
///       style = { fontSize = 24, color = "#FF0000FF", fontWeight = "bold" }
///     }
///   ''',
/// )
/// ```
class LuaPlugin extends StatelessWidget {
  final String luaScript;

  const LuaPlugin({super.key, required this.luaScript});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _executeLuaScript(luaScript),
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
          return LuaWidgetBuilder.build(context, widgetMap);
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

  /// Execute the Lua script through Rust and return the JSON result
  Future<String> _executeLuaScript(String script) async {
    // Call the Rust function through flutter_rust_bridge
    return runLuaUiScript(script: script);
  }
}
