## 0.1.0

- Initial public release as **fluau**.
- Dart tools: `LuaPluginBridge`, grants (`PluginGrantStore`), YAML package loader,
  `@LuaWidget` / `@LuaCapability` annotations, session host helpers.
- `dart run fluau:bootstrap` stamps FRB façade + Dart bridge adapter from `fluau.yaml`.
- Host owns the UI catalog; the package does not ship default widgets.
- Requires an existing Flutter–Rust bridge (e.g. flutter_rust_bridge) and the
  Rust runtime crate (git/path until published on crates.io).
