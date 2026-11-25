#!/usr/bin/env dart
// Bootstrap: stamp FRB api forwards + Dart LuaPluginBridge adapter from fluau.yaml.
//
// Assumes an existing FRB app (flutter_rust_bridge.yaml + Native Assets or Cargokit). Does NOT
// create FRB from scratch.
//
// Usage (from an app with fluau dependency):
//   dart run fluau:bootstrap
//   dart run fluau:bootstrap --config path/to/fluau.yaml
//   dart run fluau:bootstrap --generate-frb
//
// Recommended order:
//   1. Ensure rust api_module exists (this script stamps it)
//   2. flutter_rust_bridge_codegen generate
//   3. Re-run this script to refresh the Dart adapter (or use --generate-frb)

import 'dart:io';

import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  var configPath = 'fluau.yaml';
  var generateFrb = false;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--config' && i + 1 < args.length) {
      configPath = args[++i];
    } else if (args[i] == '--generate-frb') {
      generateFrb = true;
    } else if (args[i] == '--help' || args[i] == '-h') {
      stdout.writeln(
        'Usage: dart run fluau:bootstrap [--config FILE] [--generate-frb]',
      );
      exit(0);
    }
  }

  final configFile = File(configPath);
  if (!configFile.existsSync()) {
    stderr.writeln('Config not found: $configPath');
    exit(1);
  }
  final root = Directory.current.path;
  final doc = loadYaml(configFile.readAsStringSync()) as YamlMap;

  final rust = doc['rust'] as YamlMap? ?? YamlMap();
  final dart = doc['dart'] as YamlMap? ?? YamlMap();
  final crateRoot = _join(root, (rust['crate_root'] as String?) ?? 'rust/');
  final apiModuleRel = (rust['api_module'] as String?) ?? 'src/api/plugin.rs';
  final apiModule = _join(crateRoot, apiModuleRel);
  final bridgeRel =
      (dart['bridge_adapter'] as String?) ?? 'lib/fluau_bridge.g.dart';
  final bridgePath = _join(root, bridgeRel);
  final frbImport = (dart['frb_plugin_import'] as String?) ??
      'package:app/src/rust/api/plugin.dart';
  final frbVersion = (doc['frb_version'] as String?) ?? '2.13.0';

  _ensureCargoDep(crateRoot);
  _stampRustApiIfMissing(apiModule);
  _stampDartAdapter(bridgePath, frbImport);

  stdout.writeln('Stamped:');
  stdout.writeln('  Rust api:  $apiModule');
  stdout.writeln('  Dart bridge adapter: $bridgePath');
  stdout.writeln('FRB version pin: $frbVersion');
  stdout.writeln(
    'Next: flutter_rust_bridge_codegen generate  (then re-run bootstrap if needed)',
  );

  if (generateFrb) {
    stdout.writeln('Running flutter_rust_bridge_codegen generate…');
    final result = await Process.run(
      'flutter_rust_bridge_codegen',
      ['generate'],
      workingDirectory: root,
      runInShell: true,
    );
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      exit(result.exitCode);
    }
    // Refresh adapter after generate in case symbols changed.
    _stampDartAdapter(bridgePath, frbImport);
    stdout.writeln('Refreshed Dart adapter after FRB generate.');
  }
}

String _join(String a, String b) {
  if (b.startsWith('/')) return b;
  final left = a.endsWith('/') ? a.substring(0, a.length - 1) : a;
  final right = b.startsWith('./') ? b.substring(2) : b;
  return '$left${Platform.pathSeparator}$right'.replaceAll('/', Platform.pathSeparator);
}

void _ensureCargoDep(String crateRoot) {
  final cargo = File(_join(crateRoot, 'Cargo.toml'));
  if (!cargo.existsSync()) {
    stderr.writeln('Warning: no Cargo.toml at $crateRoot — skip dep check');
    return;
  }
  final text = cargo.readAsStringSync();
  if (!text.contains('fluau')) {
    stderr.writeln(
      'Warning: $cargo does not list fluau. Add:\n'
      '  fluau = "0.1"\n'
      '  # or path: fluau = { path = "../crates/fluau", version = "0.1.0" }',
    );
  }
}

void _stampRustApiIfMissing(String apiModule) {
  final file = File(apiModule);
  if (file.existsSync()) {
    stdout.writeln('Rust api module already exists — leaving in place: $apiModule');
    return;
  }
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(_rustApiTemplate);
  stdout.writeln('Created Rust api module: $apiModule');
}

void _stampDartAdapter(String bridgePath, String frbImport) {
  final file = File(bridgePath);
  file.parent.createSync(recursive: true);
  // Preserve hand-tuned adapters if they already import fluau.
  if (file.existsSync()) {
    final existing = file.readAsStringSync();
    if (existing.contains('class FrbLuaPluginBridge') &&
        existing.contains('LuaPluginBridge')) {
      stdout.writeln('Dart adapter already present — leaving in place: $bridgePath');
      return;
    }
  }
  file.writeAsStringSync(_dartAdapterTemplate(frbImport));
  stdout.writeln('Wrote Dart adapter: $bridgePath');
}

const _rustApiTemplate = r'''//! Stamped FRB façade — forwards to fluau.
//! Customize: call your app `setup()` from init; keep DTOs FRB-compatible.

use fluau::{
    self as core,
    HostApiPermission as RegistryHostApiPermission, PluginGrants as RegistryGrants,
    PluginManifest as RegistryManifest, PluginModule as RegistryModule,
    PluginPermissions as RegistryPermissions, PluginResponse as SessionPluginResponse,
};

#[derive(Clone, Debug)]
pub struct HostApiPermission {
    pub id: String,
    pub required: bool,
    pub constraints_json: String,
}

impl From<RegistryHostApiPermission> for HostApiPermission {
    fn from(value: RegistryHostApiPermission) -> Self {
        Self {
            id: value.id,
            required: value.required,
            constraints_json: value.constraints_json,
        }
    }
}

impl From<HostApiPermission> for RegistryHostApiPermission {
    fn from(value: HostApiPermission) -> Self {
        Self {
            id: value.id,
            required: value.required,
            constraints_json: value.constraints_json,
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct PluginPermissions {
    pub host: Vec<HostApiPermission>,
    pub libraries: Vec<String>,
}

impl From<RegistryPermissions> for PluginPermissions {
    fn from(value: RegistryPermissions) -> Self {
        Self {
            host: value.host.into_iter().map(Into::into).collect(),
            libraries: value.libraries,
        }
    }
}

impl From<PluginPermissions> for RegistryPermissions {
    fn from(value: PluginPermissions) -> Self {
        Self {
            host: value.host.into_iter().map(Into::into).collect(),
            libraries: value.libraries,
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct PluginGrants {
    pub host_apis: Vec<String>,
    pub libraries: Vec<String>,
}

impl From<RegistryGrants> for PluginGrants {
    fn from(value: RegistryGrants) -> Self {
        Self {
            host_apis: value.host_apis,
            libraries: value.libraries,
        }
    }
}

impl From<PluginGrants> for RegistryGrants {
    fn from(value: PluginGrants) -> Self {
        Self {
            host_apis: value.host_apis,
            libraries: value.libraries,
        }
    }
}

#[derive(Clone, Debug)]
pub struct PluginModule {
    pub name: String,
    pub source: String,
}

impl From<PluginModule> for RegistryModule {
    fn from(value: PluginModule) -> Self {
        Self {
            name: value.name,
            source: value.source,
        }
    }
}

#[derive(Clone, Debug)]
pub struct PluginManifest {
    pub id: String,
    pub name: String,
    pub version: String,
    pub script: String,
    pub main: String,
    pub capabilities: Vec<String>,
    pub permissions: PluginPermissions,
}

impl From<RegistryManifest> for PluginManifest {
    fn from(value: RegistryManifest) -> Self {
        Self {
            id: value.id,
            name: value.name,
            version: value.version,
            script: value.script,
            main: value.main,
            capabilities: value.capabilities,
            permissions: value.permissions.into(),
        }
    }
}

impl From<PluginManifest> for RegistryManifest {
    fn from(value: PluginManifest) -> Self {
        Self {
            id: value.id,
            name: value.name,
            version: value.version,
            script: value.script,
            main: value.main,
            capabilities: value.capabilities,
            permissions: value.permissions.into(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct PluginResponse {
    pub widget_json: String,
    pub provide_results: Vec<String>,
}

impl From<SessionPluginResponse> for PluginResponse {
    fn from(value: SessionPluginResponse) -> Self {
        Self {
            widget_json: value.widget_json,
            provide_results: value.provide_results,
        }
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn register_plugin(
    manifest: PluginManifest,
    script_source: String,
    modules: Vec<PluginModule>,
) -> Result<(), String> {
    core::register_plugin(
        manifest.into(),
        script_source,
        modules.into_iter().map(Into::into).collect(),
    )
}

#[flutter_rust_bridge::frb(sync)]
pub fn list_plugins() -> Result<Vec<PluginManifest>, String> {
    Ok(core::list_plugins()?.into_iter().map(Into::into).collect())
}

#[flutter_rust_bridge::frb(sync)]
pub fn get_plugin(plugin_id: String) -> Result<PluginManifest, String> {
    core::get_plugin(&plugin_id).map(Into::into)
}

#[flutter_rust_bridge::frb(sync)]
pub fn plugin_has_capability(plugin_id: String, capability: String) -> Result<bool, String> {
    core::plugin_has_capability(&plugin_id, &capability)
}

#[flutter_rust_bridge::frb(sync)]
pub fn start_registered_plugin(plugin_id: String) -> Result<(), String> {
    core::start_registered_plugin(&plugin_id)
}

#[flutter_rust_bridge::frb(sync)]
pub fn start_registered_plugin_with_grants(
    plugin_id: String,
    grants: PluginGrants,
) -> Result<(), String> {
    core::start_registered_plugin_with_grants(&plugin_id, grants.into())
}

#[flutter_rust_bridge::frb(sync)]
pub fn start_plugin(plugin_id: String, script: String) -> Result<(), String> {
    let perms = core::PluginPermissions::default();
    let grants = core::PluginGrants::default();
    core::start_plugin(&plugin_id, &script, perms, grants)
}

#[flutter_rust_bridge::frb(sync)]
pub fn stop_plugin(plugin_id: String) -> Result<(), String> {
    core::stop_plugin(&plugin_id)
}

#[flutter_rust_bridge::frb(sync)]
pub fn render_plugin(plugin_id: String) -> Result<String, String> {
    core::render_plugin(&plugin_id)
}

pub fn plugin_on_event(
    plugin_id: String,
    event_json: String,
    fields_json: Option<String>,
) -> Result<PluginResponse, String> {
    core::plugin_on_event(&plugin_id, &event_json, fields_json.as_deref()).map(Into::into)
}

pub fn call_plugin(
    plugin_id: String,
    method: String,
    args_json: String,
) -> Result<String, String> {
    core::call_plugin(&plugin_id, &method, &args_json)
}

#[derive(Clone, Debug)]
pub struct HostApiInfo {
    pub id: String,
    pub path: String,
    pub summary: String,
}

#[flutter_rust_bridge::frb(sync)]
pub fn list_host_api_info() -> Vec<HostApiInfo> {
    core::host::list_host_apis()
        .into_iter()
        .map(|e| HostApiInfo {
            id: e.id,
            path: e.path,
            summary: e.summary,
        })
        .collect()
}
''';

String _dartAdapterTemplate(String frbImport) => '''
// GENERATED/STAMPED by fluau:bootstrap — LuaPluginBridge ↔ FRB.
// Safe to edit; re-run bootstrap only if missing FrbLuaPluginBridge.

import 'dart:convert';

import 'package:fluau/fluau.dart';
import '$frbImport' as frb;

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
  String renderPlugin(String pluginId) =>
      frb.renderPlugin(pluginId: pluginId);

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
  }) =>
      frb.callPlugin(
        pluginId: pluginId,
        method: method,
        argsJson: argsJson,
      );

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
''';
