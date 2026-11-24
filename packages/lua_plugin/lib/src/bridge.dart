import 'dto.dart';

/// App-owned FFI façade. Bind once after `RustLib.init()` via [bind].
///
/// UI/events/capability payloads are JSON strings. Manifest/grants use generic
/// DTOs — this interface does **not** change when the app adds HostApis or widgets.
abstract class LuaPluginBridge {
  static LuaPluginBridge? _instance;

  /// Install the app's FRB (or other) adapter.
  static void bind(LuaPluginBridge impl) {
    _instance = impl;
  }

  static LuaPluginBridge get instance {
    final i = _instance;
    if (i == null) {
      throw StateError(
        'LuaPluginBridge.bind(...) was not called. '
        'After RustLib.init(), bind the stamped adapter (see lua_plugin bootstrap).',
      );
    }
    return i;
  }

  static bool get isBound => _instance != null;

  void registerPlugin({
    required PluginManifestDto manifest,
    required String scriptSource,
    required List<PluginModuleDto> modules,
  });

  List<PluginManifestDto> listPlugins();

  PluginManifestDto getPlugin(String pluginId);

  bool pluginHasCapability(String pluginId, String capability);

  void startRegisteredPlugin(String pluginId);

  void startRegisteredPluginWithGrants(String pluginId, PluginGrantsDto grants);

  void startPlugin(String pluginId, String script);

  void stopPlugin(String pluginId);

  String renderPlugin(String pluginId);

  Future<PluginResponseDto> pluginOnEvent({
    required String pluginId,
    required String eventJson,
    String? fieldsJson,
  });

  Future<String> callPlugin({
    required String pluginId,
    required String method,
    required String argsJson,
  });

  List<HostApiInfoDto> listHostApiInfo();
}
