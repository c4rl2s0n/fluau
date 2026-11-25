/// Load path defaults from `fluau.yaml` (optional, same file as bootstrap).

library;

import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';

const defaultCrateRoot = 'rust/';
const defaultInput = 'lib/';
const defaultWidgets = 'lib/widgets/';
const defaultLuauOut = 'assets/plugins/_types';

/// Resolved layout paths relative to [root] (usually `Directory.current`).
class FluauCodegenPaths {
  final String input;
  final String widgets;
  final String rustOut;
  final String dartOut;
  final String luauOut;
  final String? configPathUsed;

  const FluauCodegenPaths({
    required this.input,
    required this.widgets,
    required this.rustOut,
    required this.dartOut,
    required this.luauOut,
    this.configPathUsed,
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
  Map<dynamic, dynamic> codegen = const {};
  Map<dynamic, dynamic> stubs = const {};
  String? usedConfig;

  if (configFile.existsSync()) {
    usedConfig = configFile.path;
    final doc = loadYaml(configFile.readAsStringSync());
    if (doc is YamlMap) {
      rust = doc['rust'] as YamlMap? ?? const {};
      codegen = doc['codegen'] as YamlMap? ?? const {};
      stubs = doc['stubs'] as YamlMap? ?? const {};
    }
  }

  final crateRoot = _asString(rust['crate_root']) ?? defaultCrateRoot;
  final rustOut = path.normalize(
    path.join(absoluteRoot, crateRoot, 'src'),
  );

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

  final dartOutRel = _asString(codegen['dart_out']);
  final dartOut = dartOutRel != null
      ? path.normalize(path.join(absoluteRoot, dartOutRel))
      : widgets;

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
    rustOut: rustOut,
    dartOut: dartOut,
    luauOut: luauOut,
    configPathUsed: usedConfig,
  );
}

String? _asString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}
