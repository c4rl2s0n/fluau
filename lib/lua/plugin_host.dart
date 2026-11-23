import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:luatest/src/rust/api/plugin.dart';

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
  final PluginGrants? grants;
  final FieldBuffer fieldBuffer = FieldBuffer();

  String? widgetJson;
  String? error;
  bool loading = false;
  String? lastProvidedResult;
  bool _started = false;
  bool _disposed = false;

  /// Start from the Rust plugin registry (preferred).
  Future<void> startRegistered() async {
    loading = true;
    error = null;
    fieldBuffer.clear();
    _notify();
    // Let the loading overlay paint before blocking work begins.
    await Future<void>.delayed(Duration.zero);
    try {
      try {
        stopPlugin(pluginId: pluginId);
      } catch (_) {}
      final g = grants;
      if (g != null) {
        startRegisteredPluginWithGrants(pluginId: pluginId, grants: g);
      } else {
        startRegisteredPlugin(pluginId: pluginId);
      }
      _started = true;
      final boot = await pluginOnEvent(
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
        stopPlugin(pluginId: pluginId);
      } catch (_) {}
      startPlugin(pluginId: pluginId, script: script);
      _started = true;
      final boot = await pluginOnEvent(
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

    // Field edits are local-only; ignore legacy "changed" events if any arrive.
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
    // Yield so the loading spinner can paint before heavy FRB work.
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
          // Re-mark dirty so fields flush after session restart.
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

  Future<PluginResponse> _dispatch(Map<String, dynamic> event) {
    final fields = fieldBuffer.takeIfDirty();
    return pluginOnEvent(
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

  void _applyResponse(PluginResponse response) {
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
