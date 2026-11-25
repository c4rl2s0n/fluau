# fluau.yaml

Optional workspace config for `dart run fluau:bootstrap`. Analogous to
`flutter_rust_bridge.yaml`: it points bootstrap at where stamped FRB glue should
live. Paths are relative to the working directory (usually the Flutter app
root).

## Optional by default

You can run bootstrap with **no** `fluau.yaml`. Built-in defaults match a common
FRB layout (`rust/`, `src/api/fluau.rs`, `lib/fluau_bridge.g.dart`). The Dart
adapter import is inferred as
`package:<pubspec.name>/src/rust/api/fluau.dart`.

Bootstrap also:

- Registers `pub mod fluau;` in `rust/src/api/mod.rs` when missing
- Adds `fluau = "0.1"` under `[dependencies]` in `Cargo.toml` when missing

Add a config file when your Rust crate path, façade path, or adapter path
differs from those defaults — or to override `dart.frb_plugin_import` explicitly.

Use `--config path/to/fluau.yaml` if the file is not in the current directory.

## Starter template

```yaml
# Optional — omit this file to use the same defaults.
# frb_plugin_import is inferred from pubspec.yaml when omitted.
rust:
  crate_root: rust/
  # Stamped #[frb] forward module (thin façade over fluau).
  api_module: src/api/fluau.rs

dart:
  # Stamped LuaPluginBridge adapter.
  bridge_adapter: lib/fluau_bridge.g.dart

# Pin should match the app's flutter_rust_bridge dependency.
frb_version: "2.13.0"
```

Bootstrap reads only the keys above (plus optional `dart.frb_plugin_import`).
Omit any key to keep its default.

Worked example in this repo: [`example/fluau.yaml`](../../example/fluau.yaml)
(still uses `src/api/plugin.rs` for the existing example façade — new apps
default to `fluau.rs`). That file may also list `host_apis`, `frb_package`, or
`stubs` paths for human orientation; those keys are **not** consumed by
bootstrap today (stub emission is driven by the app’s `build.rs` / codegen
scripts).

## What bootstrap stamps

| Output | Config key | Behavior |
|--------|------------|----------|
| Rust FRB façade | `rust.crate_root` + `rust.api_module` | Created if missing; left alone if present |
| `api/mod.rs` | derived from `api_module` stem | Ensures `pub mod <stem>;` |
| `Cargo.toml` | — | Adds `fluau = "0.1"` under `[dependencies]` if missing |
| Dart `FrbLuaPluginBridge` | `dart.bridge_adapter` + inferred/override import | Written if missing / not already a valid adapter |

Typical order:

```bash
dart run fluau:bootstrap
flutter_rust_bridge_codegen generate
# optional: dart run fluau:bootstrap --generate-frb
```

Then bind the stamped adapter after `RustLib.init()` — see
[INTEGRATION.md](INTEGRATION.md).
