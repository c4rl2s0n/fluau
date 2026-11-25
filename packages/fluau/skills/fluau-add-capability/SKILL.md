---
name: fluau-add-capability
description: >-
  Use when adding a typed @LuaCapability / @LuaCapabilityDto contract so the
  Flutter app can call a Luau plugin without the UI tree.
---

# Add a fluau capability

## Guidelines

* Advertise capabilities in `plugin.yaml`; define the abstract Dart API + DTOs in the **app** (source of truth).
* Use `@LuaCapability('…')` and `@LuaCapabilityDto()`; let codegen emit the client and serde helpers — do not hand-write bridge methods for each capability.
* Implement Lua `dispatch(method, args)` in each plugin by hand; stubs are for LSP, not runnable dispatch.
* Prefer `build_runner` for Dart `*.g.dart` parts; use `fluau_codegen --generate-capabilities` for Luau stubs.
* Keep UI session state and capability calls coherent (shared plugin storage is the usual glue).

Docs: [Capabilities](https://github.com/c4rl2s0n/fluau/blob/main/docs/capabilities/OVERVIEW.md).

## Examples

### Declare a capability (app)

```dart
@LuaCapability('vpn.provider')
abstract class VpnProvider {
  factory VpnProvider(String pluginId) = _VpnProviderImpl;
  String get pluginId;
  bool get isCapable;
  Future<VpnStatus> getStatus();
}

@LuaCapabilityDto()
class VpnStatus {
  final bool ok;
  final String? screen;
  const VpnStatus({required this.ok, this.screen});
}
```

### Regenerate Dart parts

```bash
dart run build_runner build
```
