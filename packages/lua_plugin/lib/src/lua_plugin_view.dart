import 'package:flutter/material.dart';

import 'dto.dart';
import 'event_scope.dart';
import 'plugin_host.dart';
import 'widgets/widget.dart';

/// Renders a Lua plugin session driven by [PluginHostController].
class LuaPluginView extends StatelessWidget {
  final PluginHostController controller;

  const LuaPluginView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Plugin error: ${controller.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final map = controller.widgetMap;
        if (map == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            PluginEventScope(
              onEvent: controller.onEvent,
              fieldBuffer: controller.fieldBuffer,
              child: Builder(
                builder: (pluginContext) => SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: LuaWidgetRegistry.buildFromMap(pluginContext, map),
                ),
              ),
            ),
            if (controller.loading)
              const Positioned(
                top: 8,
                right: 8,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Starts a **registered** plugin session and renders its UI.
class LuaPlugin extends StatefulWidget {
  final String pluginId;
  final void Function(String result)? onProvideResult;

  /// Effective grants from [PluginGrantStore] / grant UI. Null ⇒ grant all requested.
  final PluginGrantsDto? grants;

  const LuaPlugin({
    super.key,
    required this.pluginId,
    this.onProvideResult,
    this.grants,
  });

  @override
  State<LuaPlugin> createState() => _LuaPluginState();
}

class _LuaPluginState extends State<LuaPlugin> {
  late final PluginHostController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PluginHostController(
      pluginId: widget.pluginId,
      onProvideResult: widget.onProvideResult,
      grants: widget.grants,
    );
    _controller.startRegistered();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LuaPluginView(controller: _controller);
  }
}
