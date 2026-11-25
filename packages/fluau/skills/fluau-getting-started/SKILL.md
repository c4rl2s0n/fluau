---
name: fluau-getting-started
description: >-
  Use when onboarding to fluau, explaining prerequisites, or helping a user run
  their first host/plugin setup with Flutter and Luau.
---

# fluau getting started

## Guidelines

* Always treat a Flutter–Rust bridge (e.g. flutter_rust_bridge) as **required**. Do not invent FRB-from-zero steps; link to FRB docs.
* Always depend on both the Dart package `fluau` (pub.dev) and the Rust crate `fluau` (crates.io).
* Prefer the published docs for deep dives: [Getting started](https://github.com/c4rl2s0n/fluau/blob/main/docs/GETTING_STARTED.md).
* For a runnable demo, clone the monorepo and run the `example/` app — do not assume widgets ship inside the Dart package.

## Examples

### Dependencies

```yaml
dependencies:
  fluau: ^0.1.2
```

```toml
[dependencies]
fluau = "0.1"

[build-dependencies]
fluau = { version = "0.1", default-features = false, features = ["stub-gen"] }
```

### Next skills

* Host integration → `fluau-integrate-host`
* Writing a plugin → `fluau-write-plugin`
