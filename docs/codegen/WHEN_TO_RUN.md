# When to regenerate

| Change | Command |
|--------|---------|
| UI catalog (`@LuaWidget` classes) | `./tool/generate.sh` (or fluau_codegen `--generate` on the catalog dir) |
| HostAPI Rust traits | `cargo build` / `flutter run` (refreshes `host.d.luau`); or `./tool/generate.sh` |
| `@LuaCapability` / DTOs | `cd example && dart run build_runner build`; Luau stubs via `./tool/generate.sh` |
| FRB-exposed Rust API | `flutter_rust_bridge_codegen generate`, then `dart run fluau:bootstrap` if the adapter drifted |
| Stamped FRB façade / Dart adapter paths | `dart run fluau:bootstrap` |

Optional freshness gate: `./tool/check_generated.sh`.

Hand-maintained: `example/assets/plugins/_types/plugin.d.luau`.

Do not paste generated file inventories into docs — the scripts above are the
source of truth for outputs.
