import 'package:flutter/widgets.dart';

import 'field_buffer.dart';

/// JSON-serializable UI event payload embedded in a Lua widget snapshot.
///
/// Prefer this over writing `Map<String, dynamic>` on `@LuaWidget` callback
/// params. Raw `Map<String, dynamic>?` remains valid for codegen.
typedef LuaEventPayload = Map<String, dynamic>;

/// Provides an event sink + field buffer so catalog widgets talk to the host.
class PluginEventScope extends InheritedWidget {
  final void Function(LuaEventPayload event) onEvent;
  final FieldBuffer fieldBuffer;

  const PluginEventScope({
    super.key,
    required this.onEvent,
    required this.fieldBuffer,
    required super.child,
  });

  static PluginEventScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<PluginEventScope>();
  }

  static void dispatch(BuildContext context, LuaEventPayload event) {
    final scope = maybeOf(context);
    assert(
      scope != null,
      'PluginEventScope.dispatch called without an ancestor PluginEventScope '
      '(wrong BuildContext — use a context under the scope).',
    );
    if (scope == null) {
      debugPrint(
        'PluginEventScope.dispatch: no scope for event $event '
        '(BuildContext is above PluginEventScope)',
      );
      return;
    }
    scope.onEvent(event);
  }

  /// Null-safe [VoidCallback] that dispatches [event] via [dispatch].
  ///
  /// Use for buttons and other nullary Flutter callbacks:
  /// `onPressed: PluginEventScope.luaEventHandler(context, onPressed)`.
  static VoidCallback? luaEventHandler(
    BuildContext context,
    LuaEventPayload? event,
  ) {
    if (event == null) return null;
    final payload = LuaEventPayload.from(event);
    return () => dispatch(context, payload);
  }

  static void setField(BuildContext context, String id, String value) {
    final scope = maybeOf(context);
    scope?.fieldBuffer.setField(id, value);
  }

  static void seedField(BuildContext context, String id, String value) {
    final scope = maybeOf(context);
    scope?.fieldBuffer.seedField(id, value);
  }

  @override
  bool updateShouldNotify(PluginEventScope oldWidget) =>
      onEvent != oldWidget.onEvent || fieldBuffer != oldWidget.fieldBuffer;
}
