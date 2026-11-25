# fluau_codegen

Code generator for [fluau](https://pub.dev/packages/fluau): keep Dart UI catalogs,
Rust UI builders, and Luau stubs aligned.

**One tool.** No `build_runner` required for fluau (avoids `build` 4/5 conflicts
with other generators).

## Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.1
```

## Default: generate everything

```bash
dart run fluau_codegen \
  --input lib \
  --rust-out rust/src \
  --dart-out lib/widgets \
  --luau-out assets/plugins/_types
```

`--input` is scanned for `@LuaCapability`. Widgets default to `lib/widgets` when
that directory exists (override with `--widgets-input`). Writes:

- `widget_serializers.g.dart`, `lua_engine.rs`, `api/lua.rs`, `ui.d.luau`
- capability `*.g.dart` parts + `capabilities.d.luau`

## Selective

```bash
dart run fluau_codegen --widgets \
  --input lib/widgets \
  --rust-out rust/src \
  --dart-out lib/widgets \
  --luau-out assets/plugins/_types

dart run fluau_codegen --capabilities \
  --input lib \
  --luau-out assets/plugins/_types
```

Deprecated aliases (one release): `--generate` → `--widgets`,
`--generate-capabilities` → `--capabilities`.

See the monorepo [WHEN_TO_RUN](https://github.com/c4rl2s0n/fluau/blob/main/docs/codegen/WHEN_TO_RUN.md)
guide for which command to run after which change.

## License

MIT
