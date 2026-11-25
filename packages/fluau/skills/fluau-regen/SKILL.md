---
name: fluau-regen
description: >-
  Use when regenerating fluau-related artifacts after annotation or FRB changes
  (widgets, capabilities, host stubs, bootstrap adapter).
---

# Regenerate fluau artifacts

## Guidelines

* One tool: [`fluau_codegen`](https://pub.dev/packages/fluau_codegen). Add it under `dev_dependencies` first. **Do not use `build_runner` for fluau.**
* Default run generates **widgets + capabilities**. Use `--widgets` or `--capabilities` only when you need a selective rebuild.
* HostAPI Rust trait changes → rebuild the app crate (`cargo build` / `flutter run`) so `stub-gen` refreshes `host.d.luau`.
* FRB-exposed API changes → `flutter_rust_bridge_codegen generate`, then `dart run fluau:bootstrap` if the stamped adapter drifted.
* Do not invent FRB-from-zero flows; do not regenerate FRB for every widget-only change.

Docs: [When to regenerate](https://github.com/c4rl2s0n/fluau/blob/main/docs/codegen/WHEN_TO_RUN.md).

## Examples

### Default (everything)

```bash
dart run fluau_codegen \
  --input lib \
  --rust-out rust/src \
  --dart-out lib/widgets \
  --luau-out assets/plugins/_types
```

### Widgets only

```bash
dart run fluau_codegen --widgets \
  --input lib/widgets \
  --rust-out rust/src \
  --dart-out lib/widgets \
  --luau-out assets/plugins/_types
```

### Capabilities only

```bash
dart run fluau_codegen --capabilities \
  --input lib \
  --luau-out assets/plugins/_types
```

### Stamped bridge adapter

```bash
dart run fluau:bootstrap
# optional: dart run fluau:bootstrap --generate-frb
```
