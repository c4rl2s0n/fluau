## 0.1.11

- Fail loudly when `@LuaWidget` params are Dart functions/`VoidCallback`
  (use `LuaEventPayload` / `Map<String, dynamic>` instead).
- Recognize `LuaEventPayload` and map typedef aliases as event-payload callbacks.
- Generated callback props accept Lua table **or** function (via
  `fluau::actions`); drop generated `ui.registerCallback`.
- Luau stubs: `UiCallback`, `ui.action`.

## 0.1.10

- Emit `enums.<Name>` value tables (Rust + Luau) for host Dart enums; optional
  `@LuaEnum(name:)` rename. Wire values remain strings.

## 0.1.9

- Generated `lua_engine` imports `fluau::mlua` / `fluau::serde_json` (no host
  Cargo `mlua`/`serde_json` required for the catalog). Dropped `_ensureCargoDeps`.

## 0.1.8

- Dotted `@LuaWidget` names nest as `ui.layout.column` (Rust tables + Luau
  stubs). JSON / Dart registry type id stays the full dotted string.

## 0.1.7

- Self-contained `lua_engine.rs`: inline catalog state/callbacks (no
  `crate::state` / `crate::callbacks`); `register_ui_catalog()` →
  `fluau::set_ui_setup`.
- Best-effort `pub mod lua_engine;` in `lib.rs` and Cargo `mlua` /
  `serde_json`. Stops regenerating FRB junk in `api/lua.rs` (retires to a
  pointer comment).
- Docs: one-liner for `#[frb(init)]`; HostAPI vs UI split.

## 0.1.6

- `@LuaWidget` classes must extend Flutter `Widget`. Registry / deserialize
  return `Widget` instances directly (no `LuaWidgetInterface`).
- Infer nested children from `Widget` / `List<Widget>`.

## 0.1.5

- (Version number reserved / superseded by 0.1.6.)

## 0.1.4

- Dart `fromJson` emits positional constructor arguments when the Dart param is
  positional (Lua/JSON keys remain named).

## 0.1.3

- Constructor-param Lua API: generative ctor parameters are the snapshot surface;
  multi-ctor auto names (`Text` / `Text_styled`); `Key` skipped; required/optional
  from nullability and Dart defaults; param annotations are rename-only.
- Standalone `widget_serializers.g.dart` under `dart.lua_root` (default
  `lib/fluau/`) — no `catalog.dart` / `part of` coupling.

## 0.1.2

- Paths from `fluau.yaml` (optional) with built-in defaults; CLI flags override.
- Zero-arg `dart run fluau_codegen` generates widgets + capabilities from the
  app root (`--config` supported).

## 0.1.1

- **CLI-only**: removed the `build_runner` SharedPartBuilder and `build` /
  `source_gen` dependencies (fixes conflicts with `build_runner` ≥2.17 / `build` 5).
- **Default generate-all**: `dart run fluau_codegen --input … --rust-out …`
  emits widgets + capabilities in one run.
- Selective flags: `--widgets`, `--capabilities`.
- Deprecated aliases: `--generate`, `--generate-capabilities`.

## 0.1.0

- Initial public release as **fluau_codegen**.
- CLI: widget catalog → Dart serializers, Rust `lua_engine.rs`, `ui.d.luau`.
- CLI: `@LuaCapability` → Luau `capabilities.d.luau` stubs + `*.g.dart` parts.
- (Removed in 0.1.1) `build_runner` SharedPartBuilder for capability Dart parts.
