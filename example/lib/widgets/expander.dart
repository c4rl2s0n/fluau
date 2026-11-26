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
class LuaExpanderWidget extends StatelessWidget {
  final String title;
  final bool? expanded;
  final LuaEventPayload? onToggle;
  final List<Widget>? children;

  const LuaExpanderWidget({
    super.key,
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
          LuaEventPayload.from(onToggle!),
        );
      },
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children ?? const [],
          ),
        ),
      ],
    );
  }
}
