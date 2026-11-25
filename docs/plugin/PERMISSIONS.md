# Permissions (request vs grant)

The **manifest** is the plugin’s request. The **grant** is what the user allowed.
Required host APIs must be granted to start a session; optional APIs may be
denied (those modules are omitted from `host` — feature-detect in Lua).

Prefer `plugin.yaml`. Exact key shapes live in example manifests and generated
`host.d.luau` stubs — do not treat this doc as a schema inventory.

## Intent

- Bare host API ids are required with no extra constraints.
- Map entries add constraints (for example HTTP domains) and may mark
  `optional: true`.
- Package modules under `modules:` / `lib/` are package content, not permissions.
- Every privileged host use re-checks the Rust `PermissionGate` (fail closed).

## Host persistence

Flutter persists decisions through `PluginGrantStore`. See
[host/GRANTS.md](../host/GRANTS.md).
