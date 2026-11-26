## 0.1.11

- Docs/skills: dotted `@LuaWidget` names → nested `ui.layout.column`.
- Align with `fluau_codegen` 0.1.8.

## 0.1.10

- Docs/skills: HostAPI vs UI split; Lua→JSON→Widget path; required
  `register_ui_catalog()` one-liner (or `ui_setup` in `fluau::setup`).
- Align with `fluau_codegen` 0.1.7.

## 0.1.9

- **Breaking:** remove `LuaWidgetInterface`. Catalog entries are Flutter
  `Widget`s (`@LuaWidget` on `StatelessWidget` / etc.). `LuaEmptyWidget` is a
  `StatelessWidget`.
- Align with `fluau_codegen` 0.1.6.

## 0.1.8

- Docs/skills: `dart.lua_root` standalone serializers; constructor-param Lua API
  (multi-ctor auto names; optional from nullability/defaults).
- Annotation docs updated for rename-only param annotations.
- Align with `fluau_codegen` 0.1.3.

## 0.1.7

- `fluau_codegen` reads paths from `fluau.yaml` (zero-arg
  `dart run fluau_codegen`). Skills/docs updated for yaml-driven codegen.
- Align with `fluau_codegen` 0.1.2.

## 0.1.6

- Skills/docs: single `fluau_codegen` CLI (default generate-all; no
  `build_runner` for fluau), install snippet, empty-`ui` warning, Frb adapter
  path / bind anti-pattern, bootstrap event, Dart↔crates version pairing, and
  an end-to-end host checklist.
- Align with `fluau_codegen` 0.1.1 (CLI-only; drops `build` ^4 conflict with
  modern `build_runner`).

## 0.1.5

- Agent skills and host/plugin docs now include the Lua entrypoint contract, a
  minimal plugin example, `fluau_codegen` flags/outputs, Rust `setup()` call-site
  story, and correct `LuaPluginBridge.bind` semantics.

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
