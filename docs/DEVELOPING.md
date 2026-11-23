# Developing the framework

This note is for people extending the host itself — the UI catalog, privileged services, or app-facing capabilities. Follow the [documentation guidelines](DOCUMENTATION_GUIDELINES.md) when you update prose after a change. For the mechanical codegen pipeline, see [CODEGEN_OVERVIEW.md](../CODEGEN_OVERVIEW.md).

## Choose an extension path

Ask what kind of power you are adding:

| Need | Path |
|------|------|
| A new visual control plugins may place in a snapshot | Grow the **UI catalog** |
| A new privileged operation every (or some) plugins may call | Extend **host services** and their permission gates |
| A stable, headless contract the Flutter app calls by name | Add a **capability** (and optionally a typed Dart facade) |
| A concrete integration users can select in the demo | Ship a **plugin package** |

Keep provider-specific logic in plugins when possible. Prefer generic host primitives (hash, HTTP, storage) over baking one vendor’s protocol into Rust.

## Growing the UI catalog

The catalog is the closed vocabulary of nodes a plugin may emit. Dart annotated widget definitions are the source of truth. Codegen derives the Lua constructors and the Dart deserializers so the snapshot format stays consistent; regenerating the flutter_rust_bridge bindings keeps the native side in sync.

Use this path when plugins need a new interaction shape (another input, layout, or feedback control) that still fits the snapshot-and-event model: values as data, presses as event maps, no live Lua callbacks across the bridge.

After adding a widget, run [`./tool/generate.sh`](../tool/generate.sh) so serializers, `lua_engine.rs`, and `ui.d.luau` stay in sync. Only run `flutter_rust_bridge_codegen generate` if you also changed FRB-exposed APIs. Then exercise the control from a small plugin before relying on it in a real package. See [CODEGEN_OVERVIEW.md](../CODEGEN_OVERVIEW.md).

## Extending host services

Host services are the privilege boundary. Add one when plugins need an operation that must not be implementable in pure Luau (or should not be duplicated in every package): networking policy, durable or shared storage, system crypto, logging sinks, and similar.

Implement new surface as annotated host traits / UserData under `rust/src/host/` (`#[host_module]`, `HostType`, `HostUserData`). Luau `host.d.luau` regenerates automatically on the next `cargo build` or `flutter run` (via `rust/build.rs`); `./tool/generate.sh` also refreshes it. Wire behavior behind the existing permission model so packages still declare what they need. Keep allowlists and sandbox assumptions intact. Document the *capability category* and threat model in architecture docs if the trust surface changes; leave call signatures in code.

## Adding capabilities

Capabilities are how the app drives a plugin without the UI tree — status queries, exporting a chosen config, logout, and so on. Define a clear method set, implement dispatch in the plugin, and optionally wrap it in a small Dart facade so the rest of the app does not speak raw JSON.

Use a capability when multiple UI flows share the same underlying contract, or when the app must act while the plugin view is not focused. Keep session state coherent between UI events and capability calls (shared plugin storage is the usual glue in the demos).

## Shipping a plugin into the demo host

Packages live as Flutter assets. The demo shell registers them at startup and offers them in its UI. Adding one is mostly packaging and wiring: asset entries, registration list, and a manifest that declares permissions and capabilities honestly.

Prefer copying the structure of an existing package over inventing a new layout. Offline stubs are valuable for host development; keep at least one that does not need real credentials.

## Dev loop

Typical iteration:

1. Change Dart catalog annotations, host Rust traits, or a plugin package.
2. Regenerate as needed:
   - UI catalog change → `./tool/generate.sh`
   - Host trait / DTO change → `flutter run` / `cargo build` is enough for `host.d.luau`, or run `./tool/generate.sh`
   - FRB API change → `flutter_rust_bridge_codegen generate`
   - Optional freshness check → `./tool/check_generated.sh`
3. Run the Linux (or other) Flutter target and select the plugin under test.

Treat architecture and plugin docs as part of the change when you alter boundaries (new trust category, new lifecycle phase, or a different UI bridge strategy). Do not update docs merely to list renamed symbols.
