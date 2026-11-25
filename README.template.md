# fluau

Sandboxed **Luau** plugins for Flutter: host-owned UI catalogs, gated host
services, and optional typed capabilities. The Dart package is `fluau`; this
repo also holds the example host and Rust runtime.

{{include:docs/GETTING_STARTED.md#prerequisite}}

{{include:docs/GETTING_STARTED.md#try-example}}

## Next steps

- [First plugin](docs/GETTING_STARTED.md#first-plugin) — copy `fake_vpn`, register assets
- [Integrate into your FRB app](docs/GETTING_STARTED.md#integrate-into-your-frb-app) — bootstrap, bind, catalog, permissions
- [When to regenerate](docs/codegen/WHEN_TO_RUN.md) — including `fluau:bootstrap` (not a first-run step)

## Repo layout

| Path | Role |
|------|------|
| `packages/fluau` | Dart tools: bridge, permission store, loader, annotations (`dart run fluau:bootstrap`) |
| `crates/lua_plugin_core` | Rust runtime (git/path until crates.io under the fluau family) |
| `example/` | Runnable host with demo HostAPIs and a sample UI catalog |
| `tool/` | Codegen + `render_readmes.dart` / `generate.sh` |

## Docs

| Audience | Start here |
|----------|------------|
| Everyone | [Getting started](docs/GETTING_STARTED.md) |
| Architecture | [concepts/ARCHITECTURE.md](docs/concepts/ARCHITECTURE.md) |
| Plugin authors | [plugin/OVERVIEW.md](docs/plugin/OVERVIEW.md), [plugin/PERMISSIONS.md](docs/plugin/PERMISSIONS.md) |
| Host integrators | [host/INTEGRATION.md](docs/host/INTEGRATION.md), [UI catalog](docs/host/UI_CATALOG.md), [Plugin permissions](docs/host/PLUGIN_PERMISSIONS.md) |
| Capabilities / codegen | [capabilities/OVERVIEW.md](docs/capabilities/OVERVIEW.md), [WHEN_TO_RUN](docs/codegen/WHEN_TO_RUN.md) |
