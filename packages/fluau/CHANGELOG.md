## 0.1.1

- Document crates.io `fluau` / `fluau_macros` and pub.dev `fluau_codegen` as the
  supported dependency story (replacing git/path `lua_plugin_core` wording).
- Bootstrap templates and host docs align with the renamed Rust crates.

## 0.1.0

- Initial public release as **fluau**.
- Dart tools: `LuaPluginBridge`, permission store (`PluginGrantStore`), YAML
  package loader, `@LuaWidget` / `@LuaCapability` annotations, session host helpers.
- `dart run fluau:bootstrap` stamps FRB façade + Dart bridge adapter from `fluau.yaml`.
- Host owns the UI catalog; the package does not ship default widgets.
- Requires an existing Flutter–Rust bridge (e.g. flutter_rust_bridge) and the
  Rust runtime crate.
