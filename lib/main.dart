import 'package:flutter/material.dart';
import 'package:luatest/lua/lua_plugin.dart';
import 'package:luatest/lua/plugin_registry.dart';
import 'package:luatest/lua/vpn_provider.dart';
import 'package:luatest/src/rust/api/plugin.dart';
import 'package:luatest/src/rust/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await PluginRegistryLoader.registerFromAssets(const [
    'assets/plugins/fake_vpn/plugin.json',
    'assets/plugins/proton_vpn/plugin.json',
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lua Plugin PoC',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const PluginDemoPage(),
    );
  }
}

class PluginDemoPage extends StatefulWidget {
  const PluginDemoPage({super.key});

  @override
  State<PluginDemoPage> createState() => _PluginDemoPageState();
}

class _PluginDemoPageState extends State<PluginDemoPage> {
  String _pluginId = 'proton-vpn';

  String? _providedResult;
  String? _contractResult;
  List<PluginManifest> _plugins = const [];
  int _session = 0;

  @override
  void initState() {
    super.initState();
    _plugins = listPlugins();
    if (_plugins.isNotEmpty && !_plugins.any((p) => p.id == _pluginId)) {
      _pluginId = _plugins.first.id;
    }
  }

  PluginManifest? get _current {
    for (final p in _plugins) {
      if (p.id == _pluginId) return p;
    }
    return _plugins.isEmpty ? null : _plugins.first;
  }

  Future<void> _useConfigViaContract() async {
    try {
      final vpn = VpnProvider(_pluginId);
      if (!vpn.isVpnProvider) {
        setState(() => _contractResult = 'Plugin is not a vpn.provider');
        return;
      }
      final result = await vpn.getSelectedConfig();
      if (!mounted) return;
      setState(() => _contractResult = result.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['ok'] == true
                ? 'Loaded config via vpn.provider contract'
                : 'Contract: ${result['error'] ?? result}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _contractResult = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    final caps = current?.capabilities.join(', ') ?? '';
    final perms = current?.permissions;

    return SelectionArea(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lua Plugin PoC'),
          actions: [
            TextButton(
              onPressed: _useConfigViaContract,
              child: const Text('Use config'),
            ),
            IconButton(
              tooltip: 'Restart plugin UI session',
              onPressed: () => setState(() {
                _session++;
                _providedResult = null;
                _contractResult = null;
              }),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButton<String>(
                      value: _plugins.any((p) => p.id == _pluginId)
                          ? _pluginId
                          : null,
                      isExpanded: true,
                      hint: const Text('Select plugin'),
                      items: _plugins
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text('${p.name} (${p.id})'),
                            ),
                          )
                          .toList(),
                      onChanged: (id) {
                        if (id == null) return;
                        setState(() {
                          _pluginId = id;
                          _session++;
                          _providedResult = null;
                          _contractResult = null;
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      current == null
                          ? 'Registry: (empty)'
                          : 'caps=[$caps] host=${perms?.host.join(",")} '
                                'http=${perms?.httpAllowlist.join(",")}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _providedResult == null
                          ? 'UI provideResult: (none yet)'
                          : 'UI provideResult: $_providedResult',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _contractResult == null
                          ? 'Contract get_selected_config: (tap Use config)'
                          : 'Contract get_selected_config: $_contractResult',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: LuaPlugin(
                key: ValueKey('plugin-$_pluginId-$_session'),
                pluginId: _pluginId,
                onProvideResult: (result) {
                  setState(() => _providedResult = result);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Plugin provided result')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
