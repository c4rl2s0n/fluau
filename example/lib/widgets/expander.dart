import 'package:flutter/material.dart';
import 'package:fluau/fluau.dart';

/// Expandable section for Lua trees (country / server accordion).
///
/// Expansion is controlled by Lua via [expanded]. Toggles dispatch [onToggle]
/// so the plugin can flip state and re-render. Prefer building [children] in
/// Lua only when expanded to keep the widget tree small.
///
/// Lua usage:
/// ```lua
/// ui.Expander {
///   title = "CH",
///   expanded = true,
///   onToggle = { type = "toggleCountry", country = "CH" },
///   children = { ui.Text { text = "…" } }
/// }
/// ```
@LuaWidget(name: 'Expander', hasChildren: true)
class LuaExpanderWidget implements LuaWidgetInterface {
  @LuaProperty(required: true)
  final String title;

  @LuaProperty()
  final bool? expanded;

  @LuaCallback()
  final Map<String, dynamic>? onToggle;

  @LuaChildren()
  final List<LuaWidgetInterface>? children;

  const LuaExpanderWidget({
    required this.title,
    this.expanded,
    this.onToggle,
    this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isExpanded = expanded ?? false;
    return ExpansionTile(
      key: ValueKey('lua-expander-$title-$isExpanded'),
      title: Text(title),
      initiallyExpanded: isExpanded,
      maintainState: false,
      onExpansionChanged: (next) {
        if (onToggle == null) return;
        if (next == isExpanded) return;
        PluginEventScope.dispatch(
          context,
          Map<String, dynamic>.from(onToggle!),
        );
      },
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children:
                children?.map((w) => w.build(context)).toList() ?? const [],
          ),
        ),
      ],
    );
  }
}
