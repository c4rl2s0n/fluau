# luatest — Luau plugin PoC for Flutter

Runtime plugins in **Luau** (sandboxed via mlua), executed through **Rust** and **flutter_rust_bridge**. Flutter hosts packages from assets, drives sandboxed sessions, and renders a fixed UI catalog from JSON snapshots.

## Docs

| Doc | For |
|-----|-----|
| [Architecture](docs/ARCHITECTURE.md) | How layers collaborate, lifecycle, trust model |
| [Plugin guide](docs/PLUGIN_GUIDE.md) | Authoring packages against the host |
| [Developing](docs/DEVELOPING.md) | Extending catalog, host services, capabilities |
| [Documentation guidelines](docs/DOCUMENTATION_GUIDELINES.md) | How we write docs in this repo |
| [Codegen overview](CODEGEN_OVERVIEW.md) | Mechanical annotation → Lua/Dart pipeline |

## What works

| Piece | Status |
|-------|--------|
| Sandboxed Luau VM per plugin session | Yes |
| Fixed UI catalog (codegen-driven) | Yes |
| Plugin packages (`plugin.yaml` + entry + modules) | Yes |
| Package-local `require` (no third-party package mgr) | Yes |
| Declared permissions (`plugin.yaml`, required/optional) | Yes |
| Grant UI + `PluginGrantStore` (memory / JSON file) | Yes |
| Central `PermissionGate` on every privileged use | Yes |
| Allowlisted HTTP domains under `http` permission | Yes |
| Generic host crypto; provider protocols in plugins | Yes |
| Fake VPN demo + ProtonVPN list-only plugin | Yes |

## Run

```bash
flutter pub get
flutter run -d linux
```

Pick **ProtonVPN** in the demo dropdown, sign in with a real Proton account, and browse servers (list-only; no tunnel). **Fake ProtonVPN** still uses stub HTTP for offline demos.

## Generated artifacts / stubs

| Artifact | Source | Updates |
|----------|--------|---------|
| `assets/plugins/_types/ui.d.luau` | Dart `@LuaWidget` catalog | `./tool/generate.sh` |
| `lib/lua/widgets/widget_serializers.g.dart` | same | same |
| `rust/src/lua_engine.rs` | same | same |
| `assets/plugins/_types/host.d.luau` | Rust `Host*` traits | **Automatic** on `cargo build` / `flutter run`; also refreshed by `./tool/generate.sh` |
| `assets/plugins/_types/plugin.d.luau` | lifecycle / intents | Hand-maintained |
| FRB Dart↔Rust glue | `#[frb]` APIs | `flutter_rust_bridge_codegen generate` when FFI changes |

This project does **not** use Dart `build_runner` for the Lua catalog — codegen is [`tool/codegen`](tool/codegen).

```bash
# After changing the UI catalog and/or host traits:
./tool/generate.sh

# Optional: fail if committed generated files are stale
./tool/check_generated.sh
```

Details: [CODEGEN_OVERVIEW.md](CODEGEN_OVERVIEW.md). For plugin editor autocomplete, install
[luau-lsp](https://github.com/JohnnyMorganz/luau-lsp); workspace settings and
`assets/plugins/.luaurc` load the definition files.

## Notes

- 2FA / human-verification UX is not implemented yet.
- Connecting a VPN tunnel is out of scope.
- Modulus PGP signature is stripped in Luau (body used); full PGP verify deferred.
