import 'package:flutter/material.dart';
import 'lua/lua_plugin.dart';

/// Main entry point for the Lua Flutter Plugin Demo app
void main() {
  runApp(const MyApp());
}

/// Root application widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lua Flutter Plugin Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const DemoScreen(),
    );
  }
}

/// Demo screen showing various Lua widget examples
class DemoScreen extends StatelessWidget {
  const DemoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lua Flutter Plugin Demo'),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Simple text widget
            LuaPlugin(
              luaScript: '''
                return ui.Text {
                  text = "Hello from Lua!",
                  size = "large",
                  color = "primary",
                  weight = "bold"
                }
              ''',
            ),
            SizedBox(height: 16),
            
            // Text with different styling
            LuaPlugin(
              luaScript: '''
                return ui.Text {
                  text = "This is a smaller text with error color",
                  size = "small",
                  color = "error"
                }
              ''',
            ),
            SizedBox(height: 16),
            
            // A button
            LuaPlugin(
              luaScript: '''
                return ui.Button {
                  text = "Click me!"
                }
              ''',
            ),
            SizedBox(height: 16),
            
            // A column with multiple children
            Expanded(
              child: LuaPlugin(
                luaScript: '''
                  return ui.Column {
                    spacing = 8,
                    mainAxisAlignment = "center",
                    crossAxisAlignment = "center",
                    children = {
                      ui.Text { text = "First" },
                      ui.Text { text = "Second", size = "medium", weight = "bold" },
                      ui.Text { text = "Third", size = "small", color = "secondary" }
                    }
                  }
                ''',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
