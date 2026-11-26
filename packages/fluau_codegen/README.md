# fluau_codegen

Code generator for [fluau](https://pub.dev/packages/fluau): keep Dart UI catalogs,
Rust UI builders, and Luau stubs aligned.

**One tool.** No `build_runner` required for fluau.

## Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.11
```

## Default: generate everything

From the Flutter app root (`fluau.yaml` optional — see
[FLUAU_YAML](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/FLUAU_YAML.md)):

```bash
dart run fluau_codegen
```

Paths resolve as **CLI flags > fluau.yaml > built-in defaults**
(`lib/`, `lib/widgets/`, `lib/fluau/`, `rust/src`, `assets/plugins/_types`).

Writes:

- `lib/fluau/widget_serializers.g.dart` (or `dart.lua_root`) — standalone library
- self-contained `lua_engine.rs` (`register_ui_catalog` / `setup_lua_api`)
- `ui.d.luau`, capability `*.g.dart` parts + `capabilities.d.luau`

Also ensures `pub mod lua_engine;` in `lib.rs`. Generated Rust imports
`fluau::mlua` / `fluau::serde_json` (no host Cargo entries for those). Call
`crate::lua_engine::register_ui_catalog()` from `#[frb(init)]` (or pass
`ui_setup` to `fluau::setup`).

The Lua surface is each public generative constructor’s parameters
(unnamed → `ui.Text`; named `styled` → `ui.Text_styled`).

## Selective / overrides

```bash
dart run fluau_codegen --widgets
dart run fluau_codegen --capabilities
dart run fluau_codegen --config path/to/fluau.yaml
dart run fluau_codegen --input lib --rust-out rust/src   # override yaml
```

## License

MIT
