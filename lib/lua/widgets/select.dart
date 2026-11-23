import 'package:flutter/material.dart';
import '../annotations.dart';
import '../event_scope.dart';
import 'widget.dart';

/// Dropdown select for Lua forms.
///
/// The selected value is buffered as a string and flushed via `flush_state`
/// when an action fires.
///
/// Lua usage:
/// ```lua
/// ui.Select {
///   id = "wg.CH#12.platform",
///   label = "Platform",
///   value = "Linux",
///   options = { "Linux", "Windows", "macOS", "Android", "iOS" }
/// }
/// ```
@LuaWidget(name: 'Select')
class LuaSelectWidget implements LuaWidgetInterface {
  @LuaProperty(required: true)
  final String id;

  @LuaProperty()
  final String? label;

  @LuaProperty()
  final String? value;

  /// Option labels/values (same string used for both).
  @LuaProperty()
  final List<String>? options;

  const LuaSelectWidget({
    required this.id,
    this.label,
    this.value,
    this.options,
  });

  @override
  Widget build(BuildContext context) {
    return _LuaSelectView(
      key: ValueKey('lua-select-$id'),
      id: id,
      label: label,
      value: value ?? '',
      options: options ?? const [],
    );
  }
}

class _LuaSelectView extends StatefulWidget {
  final String id;
  final String? label;
  final String value;
  final List<String> options;

  const _LuaSelectView({
    super.key,
    required this.id,
    required this.label,
    required this.value,
    required this.options,
  });

  @override
  State<_LuaSelectView> createState() => _LuaSelectViewState();
}

class _LuaSelectViewState extends State<_LuaSelectView> {
  late String? _value;

  @override
  void initState() {
    super.initState();
    _value = _resolveValue(widget.value, widget.options);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_value != null) {
        PluginEventScope.seedField(context, widget.id, _value!);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _LuaSelectView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value ||
        widget.options != oldWidget.options) {
      _value = _resolveValue(widget.value, widget.options);
    }
  }

  String? _resolveValue(String value, List<String> options) {
    if (options.isEmpty) return null;
    if (value.isNotEmpty && options.contains(value)) return value;
    return options.first;
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.options
        .map(
          (o) => DropdownMenuItem<String>(
            value: o,
            child: Text(o),
          ),
        )
        .toList();

    return DropdownButtonFormField<String>(
      initialValue: _value,
      items: items,
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
      ),
      onChanged: items.isEmpty
          ? null
          : (next) {
              if (next == null) return;
              setState(() => _value = next);
              PluginEventScope.setField(context, widget.id, next);
            },
    );
  }
}
