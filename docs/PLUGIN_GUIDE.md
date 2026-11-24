# Plugin author guide

This guide explains how to think about writing a Luau plugin for this host. Exact entrypoint names, manifest fields, and host call shapes live in the package manifests, example plugins, and Luau definition stubs — use those as the reference while editing.

## What a plugin is

A plugin is a **package**: a small manifest, an entry script, and optionally a `lib/` of modules the entry script can load. The host registers packages from Flutter assets, then starts a sandboxed session for a chosen package id.

Shipping a new package into the demo app means placing it under the plugins assets tree, ensuring Flutter can see those assets, and registering that package at startup. Look at the fake VPN and Proton VPN packages for complete layouts — one is an offline stub, the other talks to real APIs with vendored crypto in Luau.

## The UI and event contract

Plugins do not own a persistent Flutter widget tree. They **render a snapshot** of approved UI nodes whenever the host asks. Interaction is **event-driven**: controls embed data payloads; when the user acts, the host delivers that payload into the session and asks for a new snapshot.

Form-like controls are a special case. Their values live in a host-side buffer while the user edits. The buffer is pushed into the plugin only when an action runs, so `render` stays cheap and the plugin sees a coherent field set together with the event that used it.

A practical mental model:

- Keep plugin state in Lua locals / tables as needed.
- Use render to project that state into the fixed UI catalog.
- Use events to mutate state, kick off host work, or publish results back to the app.
- Prefer small event payloads (`type` plus a few fields) over trying to round-trip the whole UI.

## Host services and permissions

Anything privileged goes through the host: HTTP, key-value storage, crypto primitives, logging. Prefer `plugin.yaml`. Declare host APIs as a **list**:

```yaml
permissions:
  host:
    - http:
        domains:
          - api.example.com
    - db
    - log:
        optional: true
modules:
  - name: my_mod
    path: lib/my_mod.lua
```

- Bare id (`db`) ⇒ required, no extra constraints.
- Map entry ⇒ constraints plus optional meta `optional: true` (default required).
- The user grants a subset; required APIs must be allowed to run. Optional APIs may be off — guard with `if host.log then … end`.
- The framework re-checks every privileged host use (including intents); missing a grant fails closed.

**Package modules** (under `modules:` or scanned from `lib/`) are part of the plugin, not permissions. `require("my_mod")` works only for modules registered with that package. There is no filesystem/`package.path` require and no third-party package manager in the sandbox; shared or URL-fetched Luau libraries are postponed.

Two styles of host interaction coexist:

- **Direct calls** from Lua into the host surface, useful inside event handlers for straightforward request/response work.
- **Intents** returned from handlers, which the runtime drains in rounds (including follow-up hooks when async-style results come back). Useful when the plugin wants the host to own sequencing.

Prefer the style that keeps your control flow readable; the examples use both.

Crypto on the host is deliberately generic. Domain protocols (password hashing schemes, SRP proofs, provider APIs) belong in plugin modules so the host stays provider-agnostic. The Proton VPN package is the worked example of that split.

## Capabilities

UI is not the only way the app talks to a plugin. A package can advertise **capabilities** — named contracts the app may call without going through the widget tree. The host invokes a dispatch-style entry with a method name and arguments; the plugin returns structured results.

The demo uses a VPN-provider capability so the Flutter shell can ask for status, selected config, or logout through a typed facade (`@LuaCapability` + DTOs). If you add a capability, see [CAPABILITIES.md](CAPABILITIES.md): declare the abstract Dart contract, run capability codegen, implement Lua `dispatch`, and keep UI/headless state coherent (for example login session in plugin storage).

## Luau stubs and editor support

Definition files live under `assets/plugins/_types/`:

| File | Covers | Maintained by |
|------|--------|----------------|
| `ui.d.luau` | `ui.*` widget constructors | Generated (`./tool/generate.sh`) |
| `host.d.luau` | `host.db` / `host.http` / `host.crypto` / `host.log` | Generated on Cargo/Flutter build |
| `capabilities.d.luau` | capability DTO / dispatch shapes | Generated (capability codegen) |
| `plugin.d.luau` | lifecycle / intent shapes | Hand-maintained |

Install [luau-lsp](https://github.com/JohnnyMorganz/luau-lsp). Workspace settings and `assets/plugins/.luaurc` point the language server at those files. Prefer the stubs over guessing host or widget shapes.

## Authoring tips

- Start from the fake VPN package if you want a minimal login → list → provide-result flow without real network crypto.
- Use the Proton VPN package when you need multi-module structure, allowlisted HTTPS, and non-trivial Luau.
- Stay inside the published UI vocabulary. If you need a new control, that is a framework change (see [Developing](DEVELOPING.md)), not something a single plugin can invent.
