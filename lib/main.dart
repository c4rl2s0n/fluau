import 'package:flutter/material.dart';
import 'package:luatest/src/rust/api/simple.dart';
import 'package:luatest/src/rust/api/lua.dart';
import 'package:luatest/src/rust/frb_generated.dart';
import 'package:luatest/lua/lua_plugin.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

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
      home: const LuaDemoPage(),
    );
  }
}

/// Demo page that shows LuaPlugin in action
class LuaDemoPage extends StatelessWidget {
  const LuaDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lua Flutter Plugin Demo'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple text widget from Lua
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LuaPlugin(
                luaScript: '''
                  return ui.Text {
                    text = "Hello from Lua!",
                    style = { fontSize = 24, color = "#FF0000FF" }
                  }
                ''',
              ),
            ),
            
            // Text with bold style
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LuaPlugin(
                luaScript: '''
                  return ui.Text {
                    text = "Bold text from Lua",
                    style = { fontSize = 20, fontWeight = "bold" }
                  }
                ''',
              ),
            ),
            
            // Text with italic style
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LuaPlugin(
                luaScript: '''
                  return ui.Text {
                    text = "Italic text from Lua",
                    style = { fontSize = 18, fontStyle = "italic", color = "#00FF00FF" }
                  }
                ''',
              ),
            ),
            
            // Simple text without style
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LuaPlugin(
                luaScript: '''
                  return ui.Text {
                    text = "Plain text from Lua"
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
