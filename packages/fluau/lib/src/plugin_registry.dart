import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

import 'bridge.dart';
import 'dto.dart';

/// Loads plugin packages (manifest + main + lib modules) from Flutter assets.
class PluginRegistryLoader {
  /// Registers every entry in [manifestAssetPaths] (`.yaml` or `.json`).
  static Future<List<PluginManifestDto>> registerFromAssets(
    List<String> manifestAssetPaths,
  ) async {
    final registered = <PluginManifestDto>[];
    final bridge = LuaPluginBridge.instance;
    for (final path in manifestAssetPaths) {
      final raw = await rootBundle.loadString(path);
      final map = _decodeManifest(raw, path);

      final mainRel = (map['main'] as String?) ?? (map['script'] as String?);
      if (mainRel == null || mainRel.isEmpty) {
        throw StateError('plugin manifest $path missing main/script');
      }

      final manifestDir = path.contains('/')
          ? path.substring(0, path.lastIndexOf('/'))
          : '';
      final mainAsset = mainRel.startsWith('assets/')
          ? mainRel
          : (manifestDir.isEmpty ? mainRel : '$manifestDir/$mainRel');

      final script = await rootBundle.loadString(mainAsset);
      final modules = await _loadLibModules(manifestDir, map);

      final permissions = normalizePermissions(map['permissions']);

      final manifest = PluginManifestDto(
        id: map['id'] as String,
        name: map['name'] as String,
        version: map['version'] as String,
        script: mainAsset,
        main: mainRel,
        capabilities: _stringList(map['capabilities']),
        permissions: permissions,
      );

      bridge.registerPlugin(
        manifest: manifest,
        scriptSource: script,
        modules: modules,
      );
      registered.add(manifest);
    }
    return registered;
  }

  /// Prefer `plugin.yaml` next to [packageDir], else `plugin.json`.
  static Future<List<PluginManifestDto>> registerPackages(
    List<String> packageDirs,
  ) async {
    final paths = <String>[];
    for (final dir in packageDirs) {
      final yamlPath = '$dir/plugin.yaml';
      final jsonPath = '$dir/plugin.json';
      try {
        await rootBundle.loadString(yamlPath);
        paths.add(yamlPath);
        continue;
      } catch (_) {}
      paths.add(jsonPath);
    }
    return registerFromAssets(paths);
  }

  static Map<String, dynamic> _decodeManifest(String raw, String path) {
    if (path.endsWith('.yaml') || path.endsWith('.yml')) {
      final doc = loadYaml(raw);
      return _yamlToJson(doc) as Map<String, dynamic>;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  static dynamic _yamlToJson(dynamic node) {
    if (node is YamlMap) {
      return {
        for (final e in node.entries)
          e.key.toString(): _yamlToJson(e.value),
      };
    }
    if (node is YamlList) {
      return node.map(_yamlToJson).toList();
    }
    return node;
  }

  /// Normalize author `permissions` into [PluginPermissionsDto].
  static PluginPermissionsDto normalizePermissions(dynamic permissions) {
    if (permissions is! Map) {
      return const PluginPermissionsDto();
    }
    final map = Map<String, dynamic>.from(
      permissions.map((k, v) => MapEntry(k.toString(), v)),
    );
    final httpAllowlist = _stringList(
      map['httpAllowlist'] ?? map['http_allowlist'],
    );
    final host = normalizeHostList(map['host'], httpAllowlist);
    return PluginPermissionsDto(
      host: host,
      libraries: _stringList(map['libraries']),
    );
  }

  /// See plan: string | single-key map; strip `optional`; legacy string list.
  static List<HostApiPermissionDto> normalizeHostList(
    dynamic hostValue,
    List<String> httpAllowlist,
  ) {
    final out = <HostApiPermissionDto>[];
    final seen = <String>{};

    if (hostValue is! List) {
      if (hostValue is Map) {
        for (final e in hostValue.entries) {
          final id = _normalizeApiId(e.key.toString());
          if (!seen.add(id)) {
            debugPrint(
              "duplicate host API '$id' in permissions; keeping first",
            );
            continue;
          }
          final parsed = _parseBody(e.value);
          var constraints = parsed.constraints;
          if (id == 'http' &&
              !constraints.containsKey('domains') &&
              httpAllowlist.isNotEmpty) {
            constraints = {...constraints, 'domains': httpAllowlist};
          }
          out.add(
            HostApiPermissionDto(
              id: id,
              isRequired: parsed.isRequired,
              constraints: constraints,
            ),
          );
        }
      }
      return out;
    }

    final list = hostValue;
    final allStrings = list.every((e) => e is String);
    if (allStrings) {
      for (final raw in list) {
        final id = _normalizeApiId(raw.toString());
        if (!seen.add(id)) {
          debugPrint("duplicate host API '$id' in permissions; keeping first");
          continue;
        }
        final constraints = id == 'http' && httpAllowlist.isNotEmpty
            ? <String, dynamic>{'domains': httpAllowlist}
            : <String, dynamic>{};
        out.add(
          HostApiPermissionDto(
            id: id,
            isRequired: true,
            constraints: constraints,
          ),
        );
      }
      return out;
    }

    for (var i = 0; i < list.length; i++) {
      final entry = list[i];
      late final String id;
      late final dynamic body;
      if (entry is String) {
        id = _normalizeApiId(entry);
        body = <String, dynamic>{};
      } else if (entry is Map) {
        if (entry.length != 1) {
          throw FormatException(
            'permissions.host[$i]: expected a string or a single-key map',
          );
        }
        final e = entry.entries.first;
        id = _normalizeApiId(e.key.toString());
        body = e.value;
      } else {
        throw FormatException(
          'permissions.host[$i]: expected a string or a single-key map',
        );
      }
      if (!seen.add(id)) {
        debugPrint("duplicate host API '$id' in permissions; keeping first");
        continue;
      }
      final parsed = _parseBody(body);
      out.add(
        HostApiPermissionDto(
          id: id,
          isRequired: parsed.isRequired,
          constraints: parsed.constraints,
        ),
      );
    }
    return out;
  }

  static ({bool isRequired, Map<String, dynamic> constraints}) _parseBody(
    dynamic body,
  ) {
    if (body == true || body == null) {
      return (isRequired: true, constraints: <String, dynamic>{});
    }
    if (body is! Map) {
      throw FormatException(
        'permissions.host entry value must be a mapping or true',
      );
    }
    final map = Map<String, dynamic>.from(
      body.map((k, v) => MapEntry(k.toString(), v)),
    );
    var isRequired = true;
    if (map.containsKey('optional')) {
      isRequired = map.remove('optional') != true;
    }
    if (map.containsKey('required')) {
      isRequired = map.remove('required') == true;
    }
    return (isRequired: isRequired, constraints: map);
  }

  static String _normalizeApiId(String raw) {
    if (raw == 'http.request') return 'http';
    if (raw == 'logging') return 'log';
    if (raw.startsWith('crypto.')) return 'crypto';
    return raw;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }

  static Future<List<PluginModuleDto>> _loadLibModules(
    String packageDir,
    Map<String, dynamic> map,
  ) async {
    final modules = <PluginModuleDto>[];

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
        modules.add(PluginModuleDto(name: name, source: source));
      }
      return modules;
    }

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
        modules.add(PluginModuleDto(name: name, source: source));
      }
    } catch (_) {}
    return modules;
  }
}
