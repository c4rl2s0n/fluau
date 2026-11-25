---
name: fluau-write-plugin
description: >-
  Author a Luau plugin package for fluau (manifest, UI snapshots, events,
  permissions). Use when writing or editing plugin.yaml / plugin scripts.
---

# Write a fluau plugin

1. Read [docs/plugin/OVERVIEW.md](../../../docs/plugin/OVERVIEW.md) and
   [docs/plugin/PERMISSIONS.md](../../../docs/plugin/PERMISSIONS.md).
2. Copy structure from [example/assets/plugins/fake_vpn/](../../../example/assets/plugins/fake_vpn/).
3. Treat manifests and `assets/plugins/_types/*.d.luau` stubs as schema source of truth — do not invent field tables.
