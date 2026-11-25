/// Load path defaults from `fluau.yaml` (optional, same file as bootstrap).

library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

const defaultCrateRoot = 'rust/';
const defaultInput = 'lib/';
const defaultWidgets = 'lib/widgets/';
const defaultLuaRoot = 'lib/fluau/';
const defaultLuauOut = 'assets/plugins/_types';

/// Resolved layout paths relative to [root] (usually `Directory.current`).
class FluauCodegenPaths {
  /// Capability scan root.
  final String input;

  /// `@LuaWidget` scan root (sources only).
  final String widgets;

  /// Generated Dart fluau root (`widget_serializers.g.dart`, bridge default).
  final String luaRoot;

  final String rustOut;

  /// Directory that receives `widget_serializers.g.dart` (= [luaRoot]).
  final String dartOut;

  final String luauOut;
  final String? configPathUsed;
  final String? packageName;

  const FluauCodegenPaths({
    required this.input,
    required this.widgets,
    required this.luaRoot,
    required this.rustOut,
    required this.dartOut,
    required this.luauOut,
    this.configPathUsed,
    this.packageName,
  });
}

/// Load `fluau.yaml` (or [configPath]) and resolve codegen paths.
///
/// Missing file → built-in defaults. Keys omitted → per-key defaults.
FluauCodegenPaths loadCodegenPaths({
  String root = '.',
  String configPath = 'fluau.yaml',
}) {
  final absoluteRoot = path.normalize(path.absolute(root));
  final configFile = File(
    path.isAbsolute(configPath)
        ? configPath
        : path.join(absoluteRoot, configPath),
  );

  Map<dynamic, dynamic> rust = const {};
  Map<dynamic, dynamic> dart = const {};
  Map<dynamic, dynamic> codegen = const {};
  Map<dynamic, dynamic> stubs = const {};
  String? usedConfig;

  if (configFile.existsSync()) {
    usedConfig = configFile.path;
    final doc = loadYaml(configFile.readAsStringSync());
    if (doc is YamlMap) {
      rust = doc['rust'] as YamlMap? ?? const {};
      dart = doc['dart'] as YamlMap? ?? const {};
      codegen = doc['codegen'] as YamlMap? ?? const {};
      stubs = doc['stubs'] as YamlMap? ?? const {};
    }
  }

  final crateRoot = _asString(rust['crate_root']) ?? defaultCrateRoot;
  final rustOut = path.normalize(
    path.join(absoluteRoot, crateRoot, 'src'),
  );

  final luaRootRel = _asString(dart['lua_root']) ?? defaultLuaRoot;
  final luaRoot = path.normalize(path.join(absoluteRoot, luaRootRel));

  final inputRel = _asString(codegen['input']) ?? defaultInput;
  final input = path.normalize(path.join(absoluteRoot, inputRel));

  String widgets;
  final widgetsRel = _asString(codegen['widgets']);
  if (widgetsRel != null) {
    widgets = path.normalize(path.join(absoluteRoot, widgetsRel));
  } else {
    final inferred = path.normalize(path.join(absoluteRoot, defaultWidgets));
    widgets = Directory(inferred).existsSync() ? inferred : input;
  }

  // Serializers always land under lua_root (codegen.dart_out overrides for tests).
  final dartOutRel = _asString(codegen['dart_out']);
  final dartOut = dartOutRel != null
      ? path.normalize(path.join(absoluteRoot, dartOutRel))
      : luaRoot;

  String luauOut;
  final luauRel = _asString(codegen['luau_out']);
  if (luauRel != null) {
    luauOut = path.normalize(path.join(absoluteRoot, luauRel));
  } else {
    final uiStub = _asString(stubs['ui_d_luau']);
    if (uiStub != null) {
      luauOut = path.normalize(
        path.join(absoluteRoot, path.dirname(uiStub)),
      );
    } else {
      luauOut = path.normalize(path.join(absoluteRoot, defaultLuauOut));
    }
  }

  return FluauCodegenPaths(
    input: input,
    widgets: widgets,
    luaRoot: luaRoot,
    rustOut: rustOut,
    dartOut: dartOut,
    luauOut: luauOut,
    configPathUsed: usedConfig,
    packageName: _readPubspecPackageName(absoluteRoot),
  );
}

String? _readPubspecPackageName(String root) {
  final pubspec = File(path.join(root, 'pubspec.yaml'));
  if (!pubspec.existsSync()) return null;
  final doc = loadYaml(pubspec.readAsStringSync());
  if (doc is YamlMap) {
    final name = doc['name'];
    if (name is String && name.isNotEmpty) return name;
  }
  return null;
}

String? _asString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

/// Convert an absolute Dart file under `lib/` to a `package:` import URI.
String? packageImportForFile({
  required String absoluteFilePath,
  required String packageRoot,
  required String packageName,
}) {
  final libDir = path.normalize(path.join(packageRoot, 'lib'));
  final file = path.normalize(absoluteFilePath);
  final prefix = libDir.endsWith(path.separator) ? libDir : '$libDir${path.separator}';
  if (!file.startsWith(prefix)) return null;
  final rel = path.relative(file, from: libDir).replaceAll(r'\', '/');
  return 'package:$packageName/$rel';
}
