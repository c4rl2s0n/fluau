# When to regenerate

| Change | Command |
|--------|---------|
| UI catalog and/or `@LuaCapability` | `./tool/generate.sh` or `dart run fluau_codegen` from the app root |
| HostAPI Rust traits | `cargo build` / `flutter run` (refreshes `host.d.luau`); or `./tool/generate.sh` |
| FRB-exposed Rust API | `flutter_rust_bridge_codegen generate`, then `dart run fluau:bootstrap` if the adapter drifted |
| Stamped FRB façade / Dart adapter paths | `dart run fluau:bootstrap` |

### Default: generate everything

Paths come from [`fluau.yaml`](../host/FLUAU_YAML.md) (optional) with built-in
defaults. From the Flutter app root:

```bash
dart run fluau_codegen
```

Writes `widget_serializers.g.dart`, `lua_engine.rs`, `api/lua.rs`, `ui.d.luau`,
capability `*.g.dart` parts, and `capabilities.d.luau`.

### Selective / overrides

```bash
dart run fluau_codegen --widgets
dart run fluau_codegen --capabilities
dart run fluau_codegen --input lib --rust-out rust/src   # CLI overrides yaml
```

Optional freshness gate: `./tool/check_generated.sh`.

Hand-maintained: `example/assets/plugins/_types/plugin.d.luau`.
