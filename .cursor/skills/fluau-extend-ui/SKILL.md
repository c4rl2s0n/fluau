---
name: fluau-extend-ui
description: >-
  Extend the host-owned fluau UI catalog with new @LuaWidget types. Use when
  adding plugin-visible controls or changing snapshot widgets.
---

# Extend the fluau UI catalog

1. Read [docs/host/UI_CATALOG.md](../../../docs/host/UI_CATALOG.md).
2. Add `@LuaWidget` `StatelessWidget`s under
   [example/lib/widgets/](../../../example/lib/widgets/) (ctor params = Lua API).
3. Regenerate with [docs/codegen/WHEN_TO_RUN.md](../../../docs/codegen/WHEN_TO_RUN.md)
   — serializers land in `example/lib/fluau/widget_serializers.g.dart`.
