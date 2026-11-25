---
name: fluau-regen
description: >-
  Use when regenerating fluau-related artifacts after annotation or FRB changes
  (widgets, capabilities, host stubs, bootstrap adapter).
---

# Regenerate fluau artifacts

## Guidelines

* UI catalog (`@LuaWidget`) changes → run [`fluau_codegen`](https://pub.dev/packages/fluau_codegen) `--generate` (or the monorepo `./tool/generate.sh`).
* `@LuaCapability` / DTO changes → `dart run build_runner build` for Dart parts; capability Luau stubs via `fluau_codegen --generate-capabilities`.
* HostAPI Rust trait changes → rebuild the app crate (`cargo build` / `flutter run`) so `stub-gen` refreshes `host.d.luau`.
* FRB-exposed API changes → `flutter_rust_bridge_codegen generate`, then `dart run fluau:bootstrap` if the stamped adapter drifted.
* Do not invent FRB-from-zero flows; do not regenerate FRB for every widget-only change.

Docs: [When to regenerate](https://github.com/c4rl2s0n/fluau/blob/main/docs/codegen/WHEN_TO_RUN.md).

## Examples

### Capability Dart parts only

```bash
dart run build_runner build
```

### Stamped bridge adapter

```bash
dart run fluau:bootstrap
# optional: dart run fluau:bootstrap --generate-frb
```
