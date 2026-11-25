import 'dart:convert';

/// Generic DTOs shared by [LuaPluginBridge]. Stable across HostApi/widget additions.

/// One requested host API from a plugin manifest (normalized).
class HostApiPermissionDto {
  const HostApiPermissionDto({
    required this.id,
    this.isRequired = true,
    this.constraints = const {},
  });

  final String id;
  final bool isRequired;

  /// Opaque constraints (`domains`, future keys, …). HostApi-specific shape.
  final Map<String, dynamic> constraints;

  String get constraintsJson {
    if (constraints.isEmpty) return '{}';
    return jsonEncode(constraints);
  }

  factory HostApiPermissionDto.fromJson(Map<String, dynamic> json) {
    final c = json['constraints'];
    Map<String, dynamic> constraints = {};
    if (c is Map) {
      constraints = Map<String, dynamic>.from(
        c.map((k, v) => MapEntry(k.toString(), v)),
      );
    } else if (json['constraintsJson'] is String) {
      final decoded = jsonDecode(json['constraintsJson'] as String);
      if (decoded is Map) {
        constraints = Map<String, dynamic>.from(
          decoded.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    }
    return HostApiPermissionDto(
      id: json['id'] as String,
      isRequired: json['required'] as bool? ??
          json['isRequired'] as bool? ??
          true,
      constraints: constraints,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'required': isRequired,
        'constraints': constraints,
      };
}

class PluginPermissionsDto {
  const PluginPermissionsDto({
    this.host = const [],
    this.libraries = const [],
  });

  final List<HostApiPermissionDto> host;
  final List<String> libraries;
}

class PluginManifestDto {
  const PluginManifestDto({
    required this.id,
    required this.name,
    required this.version,
    this.script = '',
    this.main = '',
    this.capabilities = const [],
    this.permissions = const PluginPermissionsDto(),
  });

  final String id;
  final String name;
  final String version;
  final String script;
  final String main;
  final List<String> capabilities;
  final PluginPermissionsDto permissions;
}

class PluginModuleDto {
  const PluginModuleDto({required this.name, required this.source});

  final String name;
  final String source;
}

/// Effective grants for starting a session.
class PluginGrantsDto {
  const PluginGrantsDto({
    this.hostApis = const [],
    this.libraries = const [],
    this.constraintFingerprints = const {},
  });

  final List<String> hostApis;
  final List<String> libraries;

  /// apiId → canonical constraints JSON used when the grant was stored.
  final Map<String, String> constraintFingerprints;
}

class PluginResponseDto {
  const PluginResponseDto({
    required this.widgetJson,
    this.provideResults = const [],
  });

  final String widgetJson;
  final List<String> provideResults;
}

class HostApiInfoDto {
  const HostApiInfoDto({
    required this.id,
    required this.path,
    required this.summary,
  });

  final String id;
  final String path;
  final String summary;
}
