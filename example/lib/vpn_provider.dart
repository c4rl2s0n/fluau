import 'dart:convert';

import 'package:fluau/fluau.dart';

part 'vpn_provider.g.dart';

/// App-defined capability contract for `vpn.provider` plugins.
///
/// Advertise `capabilities: [vpn.provider]` in plugin.yaml and implement
/// Lua `dispatch`. This abstract API + DTOs are the Flutter source of truth;
/// run capability codegen for the client and Luau stubs.
///
/// DTO serde (`_$TypeFromJson` / `_$TypeToJson`) lives in the generated part;
/// declare fields + a generative constructor only.
@LuaCapability('vpn.provider')
abstract class VpnProvider {
  factory VpnProvider(String pluginId) = _VpnProviderImpl;

  String get pluginId;

  /// Whether the registered plugin advertises this capability.
  bool get isCapable;

  Future<VpnStatus> getStatus();

  Future<VpnConfigResult> getSelectedConfig();

  Future<VpnOkResult> logout();
}

@LuaCapabilityDto()
class VpnStatus {
  final bool ok;
  final String? screen;
  final String? selected;
  final String? lastServer;
  final bool? loggedIn;
  final int? serverCount;
  final String? error;

  const VpnStatus({
    required this.ok,
    this.screen,
    this.selected,
    this.lastServer,
    this.loggedIn,
    this.serverCount,
    this.error,
  });
}

@LuaCapabilityDto()
class VpnConfigResult {
  final bool ok;
  final String? config;
  final String? serverId;
  final String? serverName;
  final String? error;

  const VpnConfigResult({
    required this.ok,
    this.config,
    this.serverId,
    this.serverName,
    this.error,
  });
}

@LuaCapabilityDto()
class VpnOkResult {
  final bool ok;
  final String? error;

  const VpnOkResult({required this.ok, this.error});
}
