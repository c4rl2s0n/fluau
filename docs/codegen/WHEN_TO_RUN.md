# When to regenerate

| Change | Command |
|--------|---------|
| UI catalog (`@LuaWidget` classes) | `./tool/generate.sh` (or fluau_codegen `--generate` below) |
| HostAPI Rust traits | `cargo build` / `flutter run` (refreshes `host.d.luau`); or `./tool/generate.sh` |
| `@LuaCapability` / DTOs | `cd example && dart run build_runner build`; Luau stubs via `./tool/generate.sh` |
| FRB-exposed Rust API | `flutter_rust_bridge_codegen generate`, then `dart run fluau:bootstrap` if the adapter drifted |
| Stamped FRB façade / Dart adapter paths | `dart run fluau:bootstrap` |

### Widget catalog CLI

```bash
dart run fluau_codegen --generate \
  --input lib/widgets \
  --rust-out rust/src \
  --dart-out lib/widgets \
  --luau-out assets/plugins/_types
```

`--input`, `--rust-out`, and `--dart-out` are required; `--luau-out` defaults to
`../../assets/plugins/_types` if omitted. That run writes
`widget_serializers.g.dart` (`part of 'catalog.dart'`), `lua_engine.rs`,
`api/lua.rs`, and `ui.d.luau`.

Optional freshness gate: `./tool/check_generated.sh`.

Hand-maintained: `example/assets/plugins/_types/plugin.d.luau`.

Prefer the commands above over inventing output paths — the scripts are the
source of truth beyond the four widget-codegen artifacts listed here.
