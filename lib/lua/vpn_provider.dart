import 'dart:convert';

import 'package:luatest/src/rust/api/plugin.dart';

/// Typed Dart facade for the `vpn.provider` capability contract.
class VpnProvider {
  VpnProvider(this.pluginId);

  final String pluginId;

  static const capability = 'vpn.provider';

  bool get isVpnProvider =>
      pluginHasCapability(pluginId: pluginId, capability: capability);

  /// Headless status snapshot from Lua `dispatch("get_status", ...)`.
  Future<Map<String, dynamic>> getStatus([
    Map<String, dynamic> args = const {},
  ]) async {
    final raw = await callPlugin(
      pluginId: pluginId,
      method: 'get_status',
      argsJson: jsonEncode(args),
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  /// Headless WireGuard-like config from Lua `dispatch("get_selected_config", ...)`.
  Future<Map<String, dynamic>> getSelectedConfig([
    Map<String, dynamic> args = const {},
  ]) async {
    final raw = await callPlugin(
      pluginId: pluginId,
      method: 'get_selected_config',
      argsJson: jsonEncode(args),
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> logout() async {
    final raw = await callPlugin(
      pluginId: pluginId,
      method: 'logout',
      argsJson: '{}',
    );
    return jsonDecode(raw) as Map<String, dynamic>;
  }
}
