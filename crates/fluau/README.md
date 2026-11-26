# fluau (Rust)

Sandboxed Luau plugin runtime for Flutter hosts. Pair with the
[`fluau`](https://pub.dev/packages/fluau) Dart package and a Flutter–Rust bridge
(e.g. [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/)).

## Features

| Feature | Purpose |
|---------|---------|
| `runtime` (default) | Session, sandbox, PermissionGate, HostApi registry, re-exported macros |
| `stub-gen` | Emit `host.d.luau` stubs from annotated HostAPI sources in `build.rs` |

With `runtime`, this crate also re-exports **`mlua`** and **`serde_json`**
(`fluau::mlua`, `fluau::serde_json`) so generated `lua_engine` (and HostAPIs)
do not need separate Cargo entries for those crates. Prefer **0.1.2+** for
that surface.

## Usage

```toml
[dependencies]
fluau = "0.1"

[build-dependencies]
fluau = { version = "0.1", default-features = false, features = ["stub-gen"] }
```

```rust
use fluau::{setup, SetupOptions, host_module};
```

Proc-macros also live in [`fluau_macros`](https://crates.io/crates/fluau_macros);
prefer the re-exports from this crate.
