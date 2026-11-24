import 'package:flutter/material.dart';
import '../annotations.dart';
import '../event_scope.dart';
import 'text.dart';
import 'widget.dart';

/// Button widget definition for Lua.
///
/// Lua usage:
/// ```lua
/// ui.Button {
///   text = "Login",
///   onPressed = { type = "login" }
/// }
/// ```
@LuaWidget(name: 'Button')
class LuaButtonWidget implements LuaWidgetInterface {
  @LuaProperty()
  final String? text;

  /// Event payload forwarded to the plugin host on press.
  @LuaCallback()
  final Map<String, dynamic>? onPressed;

  @LuaProperty()
  final LuaWidgetInterface? child;

  const LuaButtonWidget({
    this.text,
    this.onPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Widget buttonChild;
    if (child != null) {
      buttonChild = child!.build(context);
    } else if (text != null) {
      buttonChild = LuaTextWidget(text: text!).build(context);
    } else {
      buttonChild = const SizedBox();
    }

    return ElevatedButton(
      onPressed: onPressed != null
          ? () => PluginEventScope.dispatch(
                context,
                Map<String, dynamic>.from(onPressed!),
              )
          : null,
      child: buttonChild,
    );
  }
}
