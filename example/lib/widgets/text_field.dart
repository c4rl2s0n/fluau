import 'package:flutter/material.dart';
import 'package:fluau/fluau.dart';

/// Text field for Lua forms.
///
/// Values are buffered locally in Flutter ([FieldBuffer]). They are flushed
/// into Lua via `flush_state` only when an action (e.g. Button) fires — not
/// on every keystroke.
///
/// Lua usage:
/// ```lua
/// ui.TextField {
///   id = "user",
///   label = "Username",
///   value = state.user,
///   obscure = false
/// }
/// ```
@LuaWidget(name: 'TextField')
class LuaTextFieldWidget implements LuaWidgetInterface {
  @LuaProperty(required: true)
  final String id;

  @LuaProperty()
  final String? label;

  @LuaProperty()
  final String? value;

  @LuaProperty()
  final bool? obscure;

  const LuaTextFieldWidget({
    required this.id,
    this.label,
    this.value,
    this.obscure,
  });

  @override
  Widget build(BuildContext context) {
    return _LuaTextFieldView(
      key: ValueKey('lua-field-$id'),
      id: id,
      label: label,
      value: value ?? '',
      obscure: obscure ?? false,
    );
  }
}

class _LuaTextFieldView extends StatefulWidget {
  final String id;
  final String? label;
  final String value;
  final bool obscure;

  const _LuaTextFieldView({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.obscure,
  });

  @override
  State<_LuaTextFieldView> createState() => _LuaTextFieldViewState();
}

class _LuaTextFieldViewState extends State<_LuaTextFieldView> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    // Seed buffer from Lua render without marking dirty.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PluginEventScope.seedField(context, widget.id, _controller.text);
    });
  }

  @override
  void didUpdateWidget(covariant _LuaTextFieldView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text && widget.value != oldWidget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      obscureText: widget.obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onChanged: (value) {
        // Local only — no Lua / no JSON rebuild.
        PluginEventScope.setField(context, widget.id, value);
      },
    );
  }
}
