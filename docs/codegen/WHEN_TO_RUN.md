# When to regenerate

| Change | Command |
|--------|---------|
| UI catalog and/or `@LuaCapability` | `./tool/generate.sh` (or `fluau_codegen` default below) |
| HostAPI Rust traits | `cargo build` / `flutter run` (refreshes `host.d.luau`); or `./tool/generate.sh` |
| FRB-exposed Rust API | `flutter_rust_bridge_codegen generate`, then `dart run fluau:bootstrap` if the adapter drifted |
| Stamped FRB façade / Dart adapter paths | `dart run fluau:bootstrap` |

### Default: generate everything

```bash
dart run fluau_codegen \
  --input lib \
  --rust-out rust/src \
  --dart-out lib/widgets \
  --luau-out assets/plugins/_types
```

`--input` is scanned for capabilities; widgets default to `lib/widgets` when that
directory exists (`--widgets-input` to override). Writes
`widget_serializers.g.dart`, `lua_engine.rs`, `api/lua.rs`, `ui.d.luau`,
capability `*.g.dart` parts, and `capabilities.d.luau`.

### Selective

```bash
dart run fluau_codegen --widgets --input lib/widgets --rust-out rust/src --dart-out lib/widgets
dart run fluau_codegen --capabilities --input lib --luau-out assets/plugins/_types
```

Optional freshness gate: `./tool/check_generated.sh`.

Hand-maintained: `example/assets/plugins/_types/plugin.d.luau`.

Prefer the commands above over inventing output paths — the scripts are the
source of truth beyond the artifacts listed here.
