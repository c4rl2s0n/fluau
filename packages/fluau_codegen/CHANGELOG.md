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
