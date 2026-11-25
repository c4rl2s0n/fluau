# fluau_codegen

Code generator for [fluau](https://pub.dev/packages/fluau): keep Dart UI catalogs,
Rust UI builders, and Luau stubs aligned.

## Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.0
  build_runner: ^2.4.14
```

## build_runner (capabilities)

```bash
dart run build_runner build
```

Emits `*.g.dart` parts for `@LuaCapability` / `@LuaCapabilityDto` in your app.

## CLI (widgets + Luau stubs)

```bash
dart run fluau_codegen --generate \
  --input path/to/widgets \
  --rust-out path/to/rust/src \
  --dart-out path/to/widgets \
  --luau-out path/to/luau/stubs

dart run fluau_codegen --generate-capabilities \
  --input path/to/lib \
  --luau-out path/to/luau/stubs
```

See the monorepo [WHEN_TO_RUN](https://github.com/c4rl2s0n/fluau/blob/main/docs/codegen/WHEN_TO_RUN.md)
guide for which command to run after which change.

## License

MIT
