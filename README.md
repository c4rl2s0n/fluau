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
| Plugin packages (manifest + entry + modules) | Yes |
| Restricted `require` for vendored modules | Yes |
| Declared permissions (enforced; grant UI later) | Yes |
| Allowlisted HTTP + stub host for offline demos | Yes |
| Generic host crypto; provider protocols in plugins | Yes |
| Fake VPN demo + ProtonVPN list-only plugin | Yes |

## Run

```bash
flutter pub get
flutter run -d linux
```

Pick **ProtonVPN** in the demo dropdown, sign in with a real Proton account, and browse servers (list-only; no tunnel). **Fake ProtonVPN** still uses stub HTTP for offline demos.

## Codegen

When you change the annotated UI catalog:

```bash
cd tool/codegen && dart pub get
dart run bin/lua_plugin_codegen.dart --generate \
  --input ../../lib/lua/widgets \
  --rust-out ../../rust/src \
  --dart-out ../../lib/lua/widgets \
  --luau-out ../../assets/plugins/_types

flutter_rust_bridge_codegen generate
```

This regenerates Rust/Dart widget bindings and Luau definition stubs under
`assets/plugins/_types/ui.d.luau`. Host stubs (`host.d.luau`) regenerate on every
`cargo build` of the Rust crate from annotated host traits (`HostDb`, `HostHttp`, …).
Lifecycle stubs (`plugin.d.luau`) remain hand-maintained.

For typed autocomplete while editing plugins, install
[luau-lsp](https://github.com/JohnnyMorganz/luau-lsp). Workspace settings load
the definition files; `assets/plugins/.luaurc` enables strict mode.

## Notes

- 2FA / human-verification UX is not implemented yet.
- Connecting a VPN tunnel is out of scope.
- Modulus PGP signature is stripped in Luau (body used); full PGP verify deferred.
