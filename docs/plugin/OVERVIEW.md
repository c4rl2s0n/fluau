# Plugin overview

A plugin is a **package**: a small manifest, an entry script, and optionally a
`lib/` of modules. The host registers packages from Flutter assets, then starts
a sandboxed session for a chosen package id.

Exact entrypoint names, manifest fields, and host call shapes live in the package
manifests, example plugins, and Luau definition stubs — use those while editing.

## UI and events

Plugins do not own a persistent Flutter widget tree. They **render a snapshot**
of approved UI nodes whenever the host asks. Interaction is **event-driven**:
controls embed data payloads; when the user acts, the host delivers that payload
into the session and asks for a new snapshot.

Form-like controls buffer values on the host until an action runs, so `render`
stays cheap and the plugin sees a coherent field set with the event.

Mental model:

- Keep plugin state in Lua locals / tables.
- Use render to project state into the host UI catalog.
- Use events to mutate state, kick off host work, or publish results.
- Prefer small event payloads (`type` plus a few fields).

## Host services

Anything privileged goes through the host (HTTP, storage, crypto, logging).
Declare requests in `plugin.yaml`; the user grants a subset. See
[PERMISSIONS.md](PERMISSIONS.md).

Two styles coexist:

- **Direct calls** from Lua into the host surface.
- **Intents** returned from handlers, drained in rounds by the runtime.

Crypto on the host is deliberately generic. Domain protocols belong in plugin
modules. The Proton VPN package is the worked example of that split.

## Capabilities

A package can advertise **capabilities** — named contracts the app may call
without the widget tree. See [capabilities/OVERVIEW.md](../capabilities/OVERVIEW.md).

## Authoring tips

- Start from `example/assets/plugins/fake_vpn/` for a minimal flow.
- Use Proton VPN when you need multi-module structure and allowlisted HTTPS.
- Stay inside the host UI vocabulary. New controls are a host catalog change
  ([UI_CATALOG.md](../host/UI_CATALOG.md)), not something one plugin invents.

## Luau stubs

Under `example/assets/plugins/_types/`:

| File | Role |
|------|------|
| `ui.d.luau` | Widget constructors (generated) |
| `host.d.luau` | Host APIs (generated on Cargo build) |
| `capabilities.d.luau` | Capability shapes (generated) |
| `plugin.d.luau` | Lifecycle / intents (hand-maintained) |

Install [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp) and point it at
those stubs.
