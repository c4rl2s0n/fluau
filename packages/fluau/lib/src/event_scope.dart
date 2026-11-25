import 'package:flutter/widgets.dart';

import 'field_buffer.dart';

/// Provides an event sink + field buffer so catalog widgets talk to the host.
class PluginEventScope extends InheritedWidget {
  final void Function(Map<String, dynamic> event) onEvent;
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

  static void dispatch(BuildContext context, Map<String, dynamic> event) {
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
