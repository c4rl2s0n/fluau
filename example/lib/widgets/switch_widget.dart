import 'package:flutter/material.dart';
import 'package:fluau/fluau.dart';

/// Boolean switch for Lua forms.
///
/// Values are buffered locally as `"true"` / `"false"` and flushed into Lua
/// via `flush_state` when an action (e.g. Download) fires.
///
/// Lua usage:
/// ```lua
/// ui.Switch {
///   id = "notifications",
///   label = "Enable notifications",
///   value = true
/// }
/// ```
@LuaWidget(name: 'Switch')
class LuaSwitchWidget extends StatelessWidget {
  final String id;
  final String? label;
  final bool? value;

  const LuaSwitchWidget({
    super.key,
    required this.id,
    this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return _LuaSwitchView(
      key: ValueKey('lua-switch-$id'),
      id: id,
      label: label,
      value: value ?? false,
    );
  }
}

class _LuaSwitchView extends StatefulWidget {
  final String id;
  final String? label;
  final bool value;

  const _LuaSwitchView({
    super.key,
    required this.id,
    required this.label,
    required this.value,
  });

  @override
  State<_LuaSwitchView> createState() => _LuaSwitchViewState();
}

class _LuaSwitchViewState extends State<_LuaSwitchView> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      PluginEventScope.seedField(
        context,
        widget.id,
        _value ? 'true' : 'false',
      );
    });
  }

  @override
  void didUpdateWidget(covariant _LuaSwitchView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _value) {
      _value = widget.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(widget.label ?? widget.id),
      value: _value,
      onChanged: (next) {
        setState(() => _value = next);
        PluginEventScope.setField(
          context,
          widget.id,
          next ? 'true' : 'false',
        );
      },
    );
  }
}
