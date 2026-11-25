# fluau.yaml

Optional workspace config for `dart run fluau:bootstrap` and
`dart run fluau_codegen`. Analogous to `flutter_rust_bridge.yaml`: it points at
where stamped FRB glue and codegen outputs live. Paths are relative to the
working directory (usually the Flutter app root).

## Optional by default

You can run bootstrap or codegen with **no** `fluau.yaml`. Built-in defaults
match a common FRB layout (`rust/`, `src/api/fluau.rs`, `lib/fluau/`,
`lib/`, `lib/widgets/`, `assets/plugins/_types`). The Dart adapter import is
inferred as `package:<pubspec.name>/src/rust/api/fluau.dart`.

Bootstrap also:

- Registers `pub mod fluau;` in `rust/src/api/mod.rs` when missing
- Adds `fluau = "0.1"` under `[dependencies]` in `Cargo.toml` when missing

Add a config file when your Rust crate path, façade path, adapter path, or
codegen layout differs from those defaults — or to override
`dart.frb_plugin_import` explicitly.

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
  # Generated Dart fluau root (bridge + widget_serializers.g.dart).
  lua_root: lib/fluau/
  # bridge_adapter defaults to <lua_root>/fluau_bridge.g.dart

codegen:
  input: lib/                 # @LuaCapability scan root
  widgets: lib/widgets/       # @LuaWidget catalog (optional)
  luau_out: assets/plugins/_types/

# Pin should match the app's flutter_rust_bridge dependency.
frb_version: "2.13.0"
```

### Who reads what

| Consumer | Keys |
|----------|------|
| `fluau:bootstrap` | `rust.crate_root`, `rust.api_module`, `dart.lua_root`, `dart.bridge_adapter`, `dart.frb_plugin_import`, `frb_version` |
| `fluau_codegen` | `rust.crate_root` → rust-out `<crate_root>/src`; `dart.lua_root` → `widget_serializers.g.dart`; `codegen.input` / `widgets` / `luau_out` / `dart_out`; if `codegen.luau_out` omitted, parent of `stubs.ui_d_luau` |

Omit any key to keep its default. Path resolution for codegen:
**CLI flags > fluau.yaml > built-in defaults**.

Worked example: [`example/fluau.yaml`](../../example/fluau.yaml) (still uses
`src/api/plugin.rs` for the existing example façade — new apps default to
`fluau.rs`).

## What bootstrap stamps

| Output | Config key | Behavior |
|--------|------------|----------|
| Rust FRB façade | `rust.crate_root` + `rust.api_module` | Created if missing; left alone if present |
| `api/mod.rs` | derived from `api_module` stem | Ensures `pub mod <stem>;` |
| `Cargo.toml` | — | Adds `fluau = "0.1"` under `[dependencies]` if missing |
| Dart `FrbLuaPluginBridge` | `dart.bridge_adapter` + inferred/override import | Written if missing / not already a valid adapter |

## Codegen

From the app root:

```bash
dart run fluau_codegen              # widgets + capabilities
dart run fluau_codegen --widgets
dart run fluau_codegen --capabilities
```

Typical bootstrap order:

```bash
dart run fluau:bootstrap
flutter_rust_bridge_codegen generate
# optional: dart run fluau:bootstrap --generate-frb
```

Then bind the stamped adapter after `RustLib.init()` — see
[INTEGRATION.md](INTEGRATION.md).
