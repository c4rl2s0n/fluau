# fluau.yaml

Optional workspace config for `dart run fluau:bootstrap`. Analogous to
`flutter_rust_bridge.yaml`: it points bootstrap at where stamped FRB glue should
live. Paths are relative to the working directory (usually the Flutter app
root).

## Optional by default

You can run bootstrap with **no** `fluau.yaml`. Built-in defaults match a common
FRB layout (`rust/`, `src/api/plugin.rs`, `lib/fluau_bridge.g.dart`).

Add a config file when:

- Your Rust crate or FRB façade path differs from those defaults
- You need a non-default Dart adapter path
- You set `dart.frb_plugin_import` to your app’s FRB-generated plugin API
  (the placeholder `package:app/...` is almost never correct for a real app)

Use `--config path/to/fluau.yaml` if the file is not in the current directory.

## Starter template

```yaml
# Optional — omit this file to use the same defaults.
rust:
  crate_root: rust/
  # Stamped #[frb] forward module (thin façade over fluau).
  api_module: src/api/plugin.rs

dart:
  # Stamped LuaPluginBridge adapter.
  bridge_adapter: lib/fluau_bridge.g.dart
  # Import of this app's FRB-generated plugin API (required for a working adapter).
  frb_plugin_import: package:your_app/src/rust/api/plugin.dart

# Pin should match the app's flutter_rust_bridge dependency.
frb_version: "2.13.0"
```

Bootstrap reads only the keys above. Omit any key to keep its default.

Worked example in this repo: [`example/fluau.yaml`](../../example/fluau.yaml).
That file may also list `host_apis`, `frb_package`, or `stubs` paths for human
orientation; those keys are **not** consumed by bootstrap today (stub emission
is driven by the app’s `build.rs` / codegen scripts).

## What bootstrap stamps

| Output | Config key | Behavior |
|--------|------------|----------|
| Rust FRB façade | `rust.crate_root` + `rust.api_module` | Created if missing; left alone if present |
| Dart `FrbLuaPluginBridge` | `dart.bridge_adapter` + `dart.frb_plugin_import` | Written if missing / not already a valid adapter |

Typical order:

```bash
dart run fluau:bootstrap
flutter_rust_bridge_codegen generate
# optional: dart run fluau:bootstrap --generate-frb
```

Then bind the stamped adapter after `RustLib.init()` — see
[INTEGRATION.md](INTEGRATION.md).
