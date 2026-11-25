---
name: fluau-integrate-host
description: >-
  Integrate fluau into an existing Flutter–Rust bridge app (bootstrap, bind,
  permissions, catalog). Use when embedding fluau in a host application.
---

# Integrate fluau into a host

1. Read [docs/host/INTEGRATION.md](../../../docs/host/INTEGRATION.md).
2. Also follow [docs/host/PLUGIN_PERMISSIONS.md](../../../docs/host/PLUGIN_PERMISSIONS.md) and
   [docs/host/UI_CATALOG.md](../../../docs/host/UI_CATALOG.md).
3. Run `dart run fluau:bootstrap` (`fluau.yaml` is optional; defaults to
   `src/api/fluau.rs` + inferred package import). See
   [docs/host/FLUAU_YAML.md](../../../docs/host/FLUAU_YAML.md);
   example still uses `plugin.rs`: [example/fluau.yaml](../../../example/fluau.yaml).
