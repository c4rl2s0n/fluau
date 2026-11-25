// Stamped by `fluau:bootstrap` — implements LuaPluginBridge
// against this app's flutter_rust_bridge generated API.
//
// After changing rust/src/api/plugin.rs (or FRB regenerating), re-run bootstrap
// if method names diverge; prefer matching the template in packages/fluau.

import 'dart:convert';

import 'package:fluau/fluau.dart';
import 'package:luatest/src/rust/api/plugin.dart' as frb;

/// FRB-backed [LuaPluginBridge] for this example app.
class FrbLuaPluginBridge implements LuaPluginBridge {
  @override
  void registerPlugin({
    required PluginManifestDto manifest,
    required String scriptSource,
    required List<PluginModuleDto> modules,
  }) {
    frb.registerPlugin(
      manifest: _toFrbManifest(manifest),
      scriptSource: scriptSource,
      modules: modules
          .map((m) => frb.PluginModule(name: m.name, source: m.source))
          .toList(),
    );
  }

  @override
  List<PluginManifestDto> listPlugins() =>
      frb.listPlugins().map(_fromFrbManifest).toList();

  @override
  PluginManifestDto getPlugin(String pluginId) =>
      _fromFrbManifest(frb.getPlugin(pluginId: pluginId));

  @override
  bool pluginHasCapability(String pluginId, String capability) =>
      frb.pluginHasCapability(pluginId: pluginId, capability: capability);

  @override
  void startRegisteredPlugin(String pluginId) =>
      frb.startRegisteredPlugin(pluginId: pluginId);

  @override
  void startRegisteredPluginWithGrants(
    String pluginId,
    PluginGrantsDto grants,
  ) {
    frb.startRegisteredPluginWithGrants(
      pluginId: pluginId,
      grants: frb.PluginGrants(
        hostApis: grants.hostApis,
        libraries: grants.libraries,
      ),
    );
  }

  @override
  void startPlugin(String pluginId, String script) =>
      frb.startPlugin(pluginId: pluginId, script: script);

  @override
  void stopPlugin(String pluginId) => frb.stopPlugin(pluginId: pluginId);

  @override
  String renderPlugin(String pluginId) => frb.renderPlugin(pluginId: pluginId);

  @override
  Future<PluginResponseDto> pluginOnEvent({
    required String pluginId,
    required String eventJson,
    String? fieldsJson,
  }) async {
    final r = await frb.pluginOnEvent(
      pluginId: pluginId,
      eventJson: eventJson,
      fieldsJson: fieldsJson,
    );
    return PluginResponseDto(
      widgetJson: r.widgetJson,
      provideResults: r.provideResults,
    );
  }

  @override
  Future<String> callPlugin({
    required String pluginId,
    required String method,
    required String argsJson,
  }) => frb.callPlugin(pluginId: pluginId, method: method, argsJson: argsJson);

  @override
  List<HostApiInfoDto> listHostApiInfo() => frb
      .listHostApiInfo()
      .map((i) => HostApiInfoDto(id: i.id, path: i.path, summary: i.summary))
      .toList();
}

frb.PluginManifest _toFrbManifest(PluginManifestDto m) {
  return frb.PluginManifest(
    id: m.id,
    name: m.name,
    version: m.version,
    script: m.script,
    main: m.main,
    capabilities: m.capabilities,
    permissions: frb.PluginPermissions(
      host: m.permissions.host
          .map(
            (h) => frb.HostApiPermission(
              id: h.id,
              required_: h.isRequired,
              constraintsJson: h.constraintsJson,
            ),
          )
          .toList(),
      libraries: m.permissions.libraries,
    ),
  );
}

PluginManifestDto _fromFrbManifest(frb.PluginManifest m) {
  return PluginManifestDto(
    id: m.id,
    name: m.name,
    version: m.version,
    script: m.script,
    main: m.main,
    capabilities: m.capabilities,
    permissions: PluginPermissionsDto(
      host: m.permissions.host.map((h) {
        Map<String, dynamic> constraints = {};
        try {
          final decoded = jsonDecode(h.constraintsJson);
          if (decoded is Map) {
            constraints = Map<String, dynamic>.from(
              decoded.map((k, v) => MapEntry(k.toString(), v)),
            );
          }
        } catch (_) {}
        return HostApiPermissionDto(
          id: h.id,
          isRequired: h.required_,
          constraints: constraints,
        );
      }).toList(),
      libraries: m.permissions.libraries,
    ),
  );
}
