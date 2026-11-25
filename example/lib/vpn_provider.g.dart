// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: require_trailing_commas, unnecessary_cast, unused_element

part of 'vpn_provider.dart';

// ignore_for_file: require_trailing_commas, unnecessary_cast, unused_element

VpnStatus _$VpnStatusFromJson(Map<String, dynamic> json) {
  final map = CapabilityJson.asMap(json, context: 'VpnStatus');
  try {
    return VpnStatus(
      ok: CapabilityJson.requireField<bool>(map, 'ok', context: 'ok'),
      screen: CapabilityJson.optionalField<String>(map, 'screen'),
      selected: CapabilityJson.optionalField<String>(map, 'selected'),
      lastServer: CapabilityJson.optionalField<String>(map, 'lastServer'),
      loggedIn: CapabilityJson.optionalField<bool>(map, 'loggedIn'),
      serverCount: CapabilityJson.optionalInt(map, 'serverCount'),
      error: CapabilityJson.optionalField<String>(map, 'error'),
    );
  } on CapabilityDecodeException {
    rethrow;
  } catch (e) {
    throw CapabilityDecodeException('VpnStatus.fromJson failed', cause: e, raw: json);
  }
}

Map<String, dynamic> _$VpnStatusToJson(VpnStatus instance) {
  return <String, dynamic>{
    'ok': instance.ok,
    'screen': instance.screen,
    'selected': instance.selected,
    'lastServer': instance.lastServer,
    'loggedIn': instance.loggedIn,
    'serverCount': instance.serverCount,
    'error': instance.error,
  };
}

VpnConfigResult _$VpnConfigResultFromJson(Map<String, dynamic> json) {
  final map = CapabilityJson.asMap(json, context: 'VpnConfigResult');
  try {
    return VpnConfigResult(
      ok: CapabilityJson.requireField<bool>(map, 'ok', context: 'ok'),
      config: CapabilityJson.optionalField<String>(map, 'config'),
      serverId: CapabilityJson.optionalField<String>(map, 'serverId'),
      serverName: CapabilityJson.optionalField<String>(map, 'serverName'),
      error: CapabilityJson.optionalField<String>(map, 'error'),
    );
  } on CapabilityDecodeException {
    rethrow;
  } catch (e) {
    throw CapabilityDecodeException('VpnConfigResult.fromJson failed', cause: e, raw: json);
  }
}

Map<String, dynamic> _$VpnConfigResultToJson(VpnConfigResult instance) {
  return <String, dynamic>{
    'ok': instance.ok,
    'config': instance.config,
    'serverId': instance.serverId,
    'serverName': instance.serverName,
    'error': instance.error,
  };
}

VpnOkResult _$VpnOkResultFromJson(Map<String, dynamic> json) {
  final map = CapabilityJson.asMap(json, context: 'VpnOkResult');
  try {
    return VpnOkResult(
      ok: CapabilityJson.requireField<bool>(map, 'ok', context: 'ok'),
      error: CapabilityJson.optionalField<String>(map, 'error'),
    );
  } on CapabilityDecodeException {
    rethrow;
  } catch (e) {
    throw CapabilityDecodeException('VpnOkResult.fromJson failed', cause: e, raw: json);
  }
}

Map<String, dynamic> _$VpnOkResultToJson(VpnOkResult instance) {
  return <String, dynamic>{
    'ok': instance.ok,
    'error': instance.error,
  };
}

class _VpnProviderImpl implements VpnProvider {
  _VpnProviderImpl(this.pluginId);

  @override
  final String pluginId;

  static const capabilityId = 'vpn.provider';

  @override
  bool get isCapable =>
      LuaPluginBridge.instance.pluginHasCapability(pluginId, capabilityId);

  @override
  Future<VpnStatus> getStatus() async {
    const argsJson = '{}';
    final raw = await LuaPluginBridge.instance.callPlugin(
      pluginId: pluginId,
      method: 'get_status',
      argsJson: argsJson,
    );
    try {
      final decoded = jsonDecode(raw);
      return _$VpnStatusFromJson(CapabilityJson.asMap(decoded, context: 'VpnStatus'));
    } on CapabilityDecodeException {
      rethrow;
    } catch (e) {
      throw CapabilityDecodeException('VpnProvider.getStatus decode failed', cause: e, raw: raw);
    }
  }

  @override
  Future<VpnConfigResult> getSelectedConfig() async {
    const argsJson = '{}';
    final raw = await LuaPluginBridge.instance.callPlugin(
      pluginId: pluginId,
      method: 'get_selected_config',
      argsJson: argsJson,
    );
    try {
      final decoded = jsonDecode(raw);
      return _$VpnConfigResultFromJson(CapabilityJson.asMap(decoded, context: 'VpnConfigResult'));
    } on CapabilityDecodeException {
      rethrow;
    } catch (e) {
      throw CapabilityDecodeException('VpnProvider.getSelectedConfig decode failed', cause: e, raw: raw);
    }
  }

  @override
  Future<VpnOkResult> logout() async {
    const argsJson = '{}';
    final raw = await LuaPluginBridge.instance.callPlugin(
      pluginId: pluginId,
      method: 'logout',
      argsJson: argsJson,
    );
    try {
      final decoded = jsonDecode(raw);
      return _$VpnOkResultFromJson(CapabilityJson.asMap(decoded, context: 'VpnOkResult'));
    } on CapabilityDecodeException {
      rethrow;
    } catch (e) {
      throw CapabilityDecodeException('VpnProvider.logout decode failed', cause: e, raw: raw);
    }
  }

}

