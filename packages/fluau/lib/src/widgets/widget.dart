import 'package:flutter/material.dart';

/// Empty widget returned for unknown widget types or error cases.
class LuaEmptyWidget extends StatelessWidget {
  const LuaEmptyWidget({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Builds a Flutter widget from a Lua UI snapshot map (`type` + properties).
typedef LuaWidgetMapBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> widgetMap,
);
