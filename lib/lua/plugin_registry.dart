import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:luatest/src/rust/api/plugin.dart';

/// Loads plugin packages (manifest + main + lib modules) from Flutter assets.
class PluginRegistryLoader {
  /// Registers every entry in [manifestAssetPaths].
  ///
  /// Supports both legacy single-file plugins (`script` → one .lua) and
  /// package layouts (`main` + optional `lib/*.lua` listed via AssetManifest
  /// under the plugin directory).
  static Future<List<PluginManifest>> registerFromAssets(
    List<String> manifestAssetPaths,
  ) async {
    final registered = <PluginManifest>[];
    for (final path in manifestAssetPaths) {
      final raw = await rootBundle.loadString(path);
      final map = jsonDecode(raw) as Map<String, dynamic>;

      final mainRel = (map['main'] as String?) ?? (map['script'] as String?);
      if (mainRel == null || mainRel.isEmpty) {
        throw StateError('plugin manifest $path missing main/script');
      }

      // Resolve main script: absolute asset path or relative to manifest dir.
      final manifestDir = path.contains('/')
          ? path.substring(0, path.lastIndexOf('/'))
          : '';
      final mainAsset = mainRel.startsWith('assets/')
          ? mainRel
          : (manifestDir.isEmpty ? mainRel : '$manifestDir/$mainRel');

      final script = await rootBundle.loadString(mainAsset);
      final modules = await _loadLibModules(manifestDir, map);

      final permissionsMap =
          (map['permissions'] as Map<String, dynamic>?) ?? const {};
      final permissions = PluginPermissions(
        host: _stringList(permissionsMap['host']),
        httpAllowlist: _stringList(
          permissionsMap['httpAllowlist'] ?? permissionsMap['http_allowlist'],
        ),
        libraries: _stringList(permissionsMap['libraries']),
      );

      final manifest = PluginManifest(
        id: map['id'] as String,
        name: map['name'] as String,
        version: map['version'] as String,
        script: mainAsset,
        main: mainRel,
        capabilities: _stringList(map['capabilities']),
        permissions: permissions,
      );

      registerPlugin(
        manifest: manifest,
        scriptSource: script,
        modules: modules,
      );
      registered.add(manifest);
    }
    return registered;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  static Future<List<PluginModule>> _loadLibModules(
    String packageDir,
    Map<String, dynamic> map,
  ) async {
    final modules = <PluginModule>[];

    // Explicit list in manifest: "modules": [{ "name": "x", "path": "lib/x.lua" }]
    final declared = map['modules'];
    if (declared is List) {
      for (final entry in declared) {
        if (entry is! Map) continue;
        final name = entry['name']?.toString();
        final rel = entry['path']?.toString();
        if (name == null || rel == null) continue;
        final asset = rel.startsWith('assets/')
            ? rel
            : (packageDir.isEmpty ? rel : '$packageDir/$rel');
        final source = await rootBundle.loadString(asset);
        modules.add(PluginModule(name: name, source: source));
      }
      return modules;
    }

    // Convention: scan AssetManifest for packageDir/lib/*.lua
    if (packageDir.isEmpty) return modules;
    try {
      final manifestJson = await rootBundle.loadString('AssetManifest.json');
      final assets = jsonDecode(manifestJson) as Map<String, dynamic>;
      final prefix = '$packageDir/lib/';
      for (final key in assets.keys) {
        if (!key.startsWith(prefix) || !key.endsWith('.lua')) continue;
        final file = key.substring(prefix.length);
        final name = file.endsWith('.lua')
            ? file.substring(0, file.length - 4)
            : file;
        if (name.contains('/')) continue;
        final source = await rootBundle.loadString(key);
        modules.add(PluginModule(name: name, source: source));
      }
    } catch (_) {
      // AssetManifest.json may be unavailable on some platforms; ignore.
    }
    return modules;
  }
}
