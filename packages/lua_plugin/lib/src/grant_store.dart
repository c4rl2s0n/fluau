import 'dart:convert';
import 'dart:io';

import 'dto.dart';

/// Persisted grant decision for one plugin package.
class StoredPluginGrants {
  StoredPluginGrants({
    required this.pluginId,
    required this.pluginVersion,
    required this.hostApis,
    required this.libraries,
    required this.constraintFingerprints,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String pluginId;
  final String pluginVersion;
  final List<String> hostApis;
  final List<String> libraries;

  /// apiId → constraintsJson snapshot used when the grant was stored.
  final Map<String, String> constraintFingerprints;
  final DateTime updatedAt;

  PluginGrantsDto toDto() => PluginGrantsDto(
        hostApis: List<String>.from(hostApis),
        libraries: List<String>.from(libraries),
        constraintFingerprints: Map<String, String>.from(constraintFingerprints),
      );

  Map<String, dynamic> toJson() => {
        'pluginId': pluginId,
        'pluginVersion': pluginVersion,
        'hostApis': hostApis,
        'libraries': libraries,
        'constraintFingerprints': constraintFingerprints,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StoredPluginGrants.fromJson(Map<String, dynamic> json) {
    final fps = <String, String>{};
    final raw = json['constraintFingerprints'];
    if (raw is Map) {
      raw.forEach((k, v) {
        fps[k.toString()] = v.toString();
      });
    }
    return StoredPluginGrants(
      pluginId: json['pluginId'] as String,
      pluginVersion: json['pluginVersion'] as String? ?? '',
      hostApis: (json['hostApis'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      libraries: (json['libraries'] as List? ?? const [])
          .map((e) => e.toString())
          .toList(),
      constraintFingerprints: fps,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// Whether this stored grant still covers [manifest] required APIs and
  /// matching constraint fingerprints for granted APIs.
  bool covers(PluginManifestDto manifest) {
    if (pluginVersion != manifest.version) return false;
    final granted = hostApis.toSet();
    for (final req in manifest.permissions.host) {
      if (req.isRequired && !granted.contains(req.id)) return false;
      if (granted.contains(req.id)) {
        final prev = constraintFingerprints[req.id];
        if (prev != null && prev != req.constraintsJson) return false;
      }
    }
    return true;
  }

  static StoredPluginGrants fromManifestSelection({
    required PluginManifestDto manifest,
    required Set<String> selectedHostApis,
  }) {
    final fps = <String, String>{};
    for (final req in manifest.permissions.host) {
      if (selectedHostApis.contains(req.id)) {
        fps[req.id] = req.constraintsJson;
      }
    }
    return StoredPluginGrants(
      pluginId: manifest.id,
      pluginVersion: manifest.version,
      hostApis: selectedHostApis.toList()..sort(),
      libraries: List<String>.from(manifest.permissions.libraries),
      constraintFingerprints: fps,
    );
  }
}

/// Swappable persistence for plugin permission grants.
abstract class PluginGrantStore {
  Future<StoredPluginGrants?> read(String pluginId);
  Future<void> write(StoredPluginGrants grants);
  Future<void> clear(String pluginId);
}

/// In-memory store for tests and ephemeral demos.
class MemoryPluginGrantStore implements PluginGrantStore {
  final Map<String, StoredPluginGrants> _data = {};

  @override
  Future<StoredPluginGrants?> read(String pluginId) async => _data[pluginId];

  @override
  Future<void> write(StoredPluginGrants grants) async {
    _data[grants.pluginId] = grants;
  }

  @override
  Future<void> clear(String pluginId) async {
    _data.remove(pluginId);
  }
}

/// JSON file store (one file, map of pluginId → grant). Path is injected by the app.
class JsonFilePluginGrantStore implements PluginGrantStore {
  JsonFilePluginGrantStore(this.filePath);

  final String filePath;

  Future<Map<String, dynamic>> _load() async {
    final file = File(filePath);
    if (!await file.exists()) return {};
    try {
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {}
    return {};
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  @override
  Future<StoredPluginGrants?> read(String pluginId) async {
    final data = await _load();
    final entry = data[pluginId];
    if (entry is! Map) return null;
    return StoredPluginGrants.fromJson(
      entry.map((k, v) => MapEntry(k.toString(), v)),
    );
  }

  @override
  Future<void> write(StoredPluginGrants grants) async {
    final data = await _load();
    data[grants.pluginId] = grants.toJson();
    await _save(data);
  }

  @override
  Future<void> clear(String pluginId) async {
    final data = await _load();
    data.remove(pluginId);
    await _save(data);
  }
}
