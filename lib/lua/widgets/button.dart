import 'package:flutter/material.dart';
import '../annotations.dart';
import 'widget.dart';
import 'text.dart';
import 'package:luatest/src/rust/api/lua.dart';

/// Button widget definition for Lua
///
/// This is a dataclass (not a StatelessWidget) that defines the structure
/// of a Button widget that can be created from Lua.
///
/// Lua usage:
///   ui.Button {
///     text = "Click me!",
///     onPressed = function() print("Clicked!") end
///   }
@LuaWidget(name: 'Button')
class LuaButtonWidget implements LuaWidgetInterface {
  /// The text to display on the button
  @LuaProperty()
  final String? text;
  
  /// Callback to execute when the button is pressed
  /// This will be a callback ID registered via ui.registerCallback()
  @LuaCallback()
  final String? onPressed;
  
  /// Child widget (alternative to text)
  @LuaProperty()
  final LuaWidgetInterface? child;
  
  const LuaButtonWidget({
    this.text,
    this.onPressed,
    this.child,
  });
  
  /// Build the Flutter ElevatedButton widget from this definition
  Widget build(BuildContext context) {
    // Determine the child widget
    Widget buttonChild;
    if (child != null) {
      buttonChild = child!.build(context);
    } else if (text != null) {
      // Create a text widget for the button
      buttonChild = LuaTextWidget(
        text: text!,
        // Use default styling for button text
      ).build(context);
    } else {
      buttonChild = const SizedBox();
    }
    
    return ElevatedButton(
      onPressed: onPressed != null ? () => _executeCallback(onPressed!) : null,
      child: buttonChild,
    );
  }
  
  /// Execute a Lua callback by ID
  Future<void> _executeCallback(String callbackId) async {
    try {
      // Call the Rust FFI to execute the Lua callback
      await executeLuaCallback(callbackId: callbackId);
    } catch (e) {
      debugPrint('Lua callback error: $e');
    }
  }
}
