import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'bridge.dart';
import 'dto.dart';
import 'field_buffer.dart';

/// Thin Flutter host for a persistent Lua plugin session.
///
/// Form fields are buffered locally ([fieldBuffer]) and flushed into Lua via
/// `flush_state` only when an action event is dispatched.
///
/// Important: [dispose] does **not** call `stopPlugin` (refresh race).
class PluginHostController extends ChangeNotifier {
  PluginHostController({
    required this.pluginId,
    this.onProvideResult,
    this.grants,
  });

  final String pluginId;
  final void Function(String value)? onProvideResult;

  /// When set, starts with these grants; otherwise grants all requested APIs.
  final PluginGrantsDto? grants;
  final FieldBuffer fieldBuffer = FieldBuffer();

  String? widgetJson;
  String? error;
  bool loading = false;
  String? lastProvidedResult;
  bool _started = false;
  bool _disposed = false;

  LuaPluginBridge get _bridge => LuaPluginBridge.instance;

  /// Start from the Rust plugin registry (preferred).
  Future<void> startRegistered() async {
    loading = true;
    error = null;
    fieldBuffer.clear();
    _notify();
    await Future<void>.delayed(Duration.zero);
    try {
      try {
        _bridge.stopPlugin(pluginId);
      } catch (_) {}
      final g = grants;
      if (g != null) {
        _bridge.startRegisteredPluginWithGrants(pluginId, g);
      } else {
        _bridge.startRegisteredPlugin(pluginId);
      }
      _started = true;
      final boot = await _bridge.pluginOnEvent(
        pluginId: pluginId,
        eventJson: jsonEncode({'type': 'bootstrap'}),
        fieldsJson: null,
      );
      _applyResponse(boot);
    } catch (e) {
      error = e.toString();
      _started = false;
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Legacy: start with an explicit script string.
  Future<void> start(String script) async {
    loading = true;
    error = null;
    fieldBuffer.clear();
    _notify();
    await Future<void>.delayed(Duration.zero);
    try {
      try {
        _bridge.stopPlugin(pluginId);
      } catch (_) {}
      _bridge.startPlugin(pluginId, script);
      _started = true;
      final boot = await _bridge.pluginOnEvent(
        pluginId: pluginId,
        eventJson: jsonEncode({'type': 'bootstrap'}),
        fieldsJson: null,
      );
      _applyResponse(boot);
    } catch (e) {
      error = e.toString();
      _started = false;
    } finally {
      loading = false;
      _notify();
    }
  }

  void detach() {
    _started = false;
  }

  @override
  void dispose() {
    _disposed = true;
    detach();
    super.dispose();
  }

  Future<void> onEvent(Map<String, dynamic> event) async {
    if (_disposed || !_started) return;

    if (event['type'] == 'changed') {
      final id = event['id']?.toString();
      final value = event['value']?.toString() ?? '';
      if (id != null) {
        fieldBuffer.setField(id, value);
      }
      return;
    }

    loading = true;
    error = null;
    _notify();
    await Future<void>.delayed(Duration.zero);
    try {
      final response = await _dispatch(event);
      _applyResponse(response);
    } catch (e) {
      final message = e.toString();
      if (_isSessionMissing(message)) {
        try {
          await startRegistered();
          if (_disposed || !_started) return;
          fieldBuffer.dirty = true;
          final response = await _dispatch(event);
          _applyResponse(response);
          error = null;
        } catch (e2) {
          error = e2.toString();
        }
      } else {
        error = message;
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  Future<PluginResponseDto> _dispatch(Map<String, dynamic> event) {
    final fields = fieldBuffer.takeIfDirty();
    return _bridge.pluginOnEvent(
      pluginId: pluginId,
      eventJson: jsonEncode(event),
      fieldsJson: fields == null ? null : jsonEncode(fields),
    );
  }

  bool _isSessionMissing(String message) {
    final lower = message.toLowerCase();
    return lower.contains('session not found') ||
        lower.contains('plugin not found');
  }

  void _applyResponse(PluginResponseDto response) {
    widgetJson = response.widgetJson;
    for (final value in response.provideResults) {
      lastProvidedResult = value;
      onProvideResult?.call(value);
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Map<String, dynamic>? get widgetMap {
    final json = widgetJson;
    if (json == null) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
