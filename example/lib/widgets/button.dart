import 'package:flutter/material.dart';
import 'package:fluau/fluau.dart';
import 'text.dart';

/// Button widget for Lua.
///
/// Lua usage:
/// ```lua
/// ui.Button {
///   text = "Login",
///   onPressed = { type = "login" }
/// }
/// ```
@LuaWidget(name: 'Button')
class LuaButtonWidget extends StatelessWidget {
  final String? text;
  final Map<String, dynamic>? onPressed;
  final Widget? child;

  const LuaButtonWidget({
    super.key,
    this.text,
    this.onPressed,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final Widget buttonChild;
    if (child != null) {
      buttonChild = child!;
    } else if (text != null) {
      buttonChild = LuaTextWidget(text: text!);
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
