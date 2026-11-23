import 'dart:io';

import 'package:flutter/material.dart';
import 'package:luatest/lua/grant_sheet.dart';
import 'package:luatest/lua/grant_store.dart';
import 'package:luatest/lua/lua_plugin.dart';
import 'package:luatest/lua/plugin_registry.dart';
import 'package:luatest/lua/vpn_provider.dart';
import 'package:luatest/src/rust/api/plugin.dart';
import 'package:luatest/src/rust/frb_generated.dart';

late PluginGrantStore grantStore;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();

  // Persist grants under a local file (path injected — swap store for other backends).
  final grantsPath =
      '${Directory.systemTemp.path}${Platform.pathSeparator}luatest_plugin_grants.json';
  grantStore = JsonFilePluginGrantStore(grantsPath);

  await PluginRegistryLoader.registerPackages(const [
    'assets/plugins/fake_vpn',
    'assets/plugins/proton_vpn',
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
  PluginGrants? _activeGrants;
  bool _resolvingGrants = true;

  @override
  void initState() {
    super.initState();
    _plugins = listPlugins();
    if (_plugins.isNotEmpty && !_plugins.any((p) => p.id == _pluginId)) {
      _pluginId = _plugins.first.id;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureGrants());
  }

  PluginManifest? get _current {
    for (final p in _plugins) {
      if (p.id == _pluginId) return p;
    }
    return _plugins.isEmpty ? null : _plugins.first;
  }

  Future<void> _ensureGrants({bool forcePrompt = false}) async {
    final manifest = _current;
    if (manifest == null) {
      setState(() {
        _resolvingGrants = false;
        _activeGrants = null;
      });
      return;
    }
    setState(() => _resolvingGrants = true);

    final previous = await grantStore.read(manifest.id);
    if (!forcePrompt && previous != null && previous.covers(manifest)) {
      setState(() {
        _activeGrants = previous.toFrb();
        _resolvingGrants = false;
      });
      return;
    }

    if (!mounted) return;
    final decided = await showPluginGrantSheet(
      context: context,
      manifest: manifest,
      previous: previous,
    );
    if (decided == null) {
      setState(() {
        _activeGrants = null;
        _resolvingGrants = false;
      });
      return;
    }
    await grantStore.write(decided);
    setState(() {
      _activeGrants = decided.toFrb();
      _resolvingGrants = false;
      _session++;
    });
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

  String _permsSummary(PluginPermissions? perms) {
    if (perms == null) return '';
    final parts = perms.host.map((h) {
      final tag = h.required_ ? 'req' : 'opt';
      return '${h.id}($tag)';
    });
    return parts.join(', ');
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
              tooltip: 'Review permissions',
              onPressed: () => _ensureGrants(forcePrompt: true),
              icon: const Icon(Icons.security),
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
                      onChanged: (id) async {
                        if (id == null) return;
                        setState(() {
                          _pluginId = id;
                          _session++;
                          _providedResult = null;
                          _contractResult = null;
                          _activeGrants = null;
                        });
                        await _ensureGrants();
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      current == null
                          ? 'Registry: (empty)'
                          : 'caps=[$caps] host=${_permsSummary(perms)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _activeGrants == null
                          ? 'Grants: (none — allow the plugin to run)'
                          : 'Grants: ${_activeGrants!.hostApis.join(", ")}',
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
              child: _resolvingGrants
                  ? const Center(child: CircularProgressIndicator())
                  : _activeGrants == null
                      ? Center(
                          child: FilledButton(
                            onPressed: () => _ensureGrants(forcePrompt: true),
                            child: const Text('Review permissions'),
                          ),
                        )
                      : LuaPlugin(
                          key: ValueKey(
                            'plugin-$_pluginId-$_session-${_activeGrants!.hostApis.join(",")}',
                          ),
                          pluginId: _pluginId,
                          grants: _activeGrants,
                          onProvideResult: (result) {
                            setState(() => _providedResult = result);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Plugin provided result'),
                              ),
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
