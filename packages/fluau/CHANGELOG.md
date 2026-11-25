## 0.1.4

- Bootstrap infers `frb_plugin_import` from `pubspec.yaml` and defaults the Rust
  façade to `src/api/fluau.rs`.
- Registers `pub mod <stem>;` in `api/mod.rs` and adds `fluau = "0.1"` to
  `Cargo.toml` when missing.

## 0.1.3

- `fluau.yaml` is optional for `dart run fluau:bootstrap` (built-in defaults when
  missing); warn when `frb_plugin_import` is still the placeholder.
- Document the config starter in Getting Started and `docs/host/FLUAU_YAML.md`.

## 0.1.2

- Ship Agent Skills under `skills/` for consumers (`dart run skills@ get`).
- Cover getting started, host integration, plugins, permissions, UI catalog,
  capabilities, and regen workflows.

## 0.1.1

- Document crates.io `fluau` / `fluau_macros` and pub.dev `fluau_codegen` as the
  supported dependency story (replacing git/path `lua_plugin_core` wording).
- Bootstrap templates and host docs align with the renamed Rust crates.

## 0.1.0

- Initial public release as **fluau**.
- Dart tools: `LuaPluginBridge`, permission store (`PluginGrantStore`), YAML
  package loader, `@LuaWidget` / `@LuaCapability` annotations, session host helpers.
- `dart run fluau:bootstrap` stamps FRB façade + Dart bridge adapter from `fluau.yaml`.
- Host owns the UI catalog; the package does not ship default widgets.
- Requires an existing Flutter–Rust bridge (e.g. flutter_rust_bridge) and the
  Rust runtime crate.
