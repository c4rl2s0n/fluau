# fluau_macros

Procedural macros for [fluau](https://crates.io/crates/fluau) host APIs:

- `#[host_module]`
- `#[host_userdata]`
- `#[derive(HostType)]` / `#[derive(HostUserData)]`

Prefer depending on the [`fluau`](https://crates.io/crates/fluau) crate, which
re-exports these macros. Direct use of `fluau_macros` is only needed in advanced
setups.
