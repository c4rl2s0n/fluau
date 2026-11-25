# fluau_codegen

Code generator for [fluau](https://pub.dev/packages/fluau): keep Dart UI catalogs,
Rust UI builders, and Luau stubs aligned.

**One tool.** No `build_runner` required for fluau.

## Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.2
```

## Default: generate everything

From the Flutter app root (`fluau.yaml` optional — see
[FLUAU_YAML](https://github.com/c4rl2s0n/fluau/blob/main/docs/host/FLUAU_YAML.md)):

```bash
dart run fluau_codegen
```

Paths resolve as **CLI flags > fluau.yaml > built-in defaults**
(`lib/`, `lib/widgets/`, `rust/src`, `assets/plugins/_types`).

Writes:

- `widget_serializers.g.dart`, `lua_engine.rs`, `api/lua.rs`, `ui.d.luau`
- capability `*.g.dart` parts + `capabilities.d.luau`

## Selective / overrides

```bash
dart run fluau_codegen --widgets
dart run fluau_codegen --capabilities
dart run fluau_codegen --config path/to/fluau.yaml
dart run fluau_codegen --input lib --rust-out rust/src   # override yaml
```

## License

MIT
