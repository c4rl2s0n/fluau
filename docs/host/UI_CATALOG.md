# Host-owned UI catalog

fluau does **not** ship default widgets. The host defines the closed vocabulary
plugins may emit. That keeps trust clear and lets each app theme and constrain
controls itself.

## How a snapshot reaches Flutter

```
Luau plugin                  Rust (codegen)              Dart
─────────────                ──────────────              ────
ui.Column { … }  ──ctors──►  JSON string                 JSON → Widget
                             (type + props)  ──session──► LuaWidgetRegistry
                                                          .buildFromMap
```

Generated `ui.*` builders are the closed-catalog **encoder**: they set `type`,
validate required/enum fields, and return a JSON string. Dart serializers are
only JSON→Widget. A Lua table is not JSON — something must encode at the
boundary; keep the builders (do not hand-write JSON in plugins).

## HostAPI registry vs UI registry

Keep them **separable**:

| Registry | Changes | How to register |
|----------|---------|-----------------|
| HostAPIs (`db`, `http`, …) | Rare, app-specific | `fluau::setup(SetupOptions { host_apis, … })` |
| UI catalog (`ui.*`) | Often (codegen) | `register_ui_catalog()` **or** `ui_setup: Some(setup_lua_api)` |

`fluau::setup` **clears** UI registration, then applies `ui_setup` if provided.
If you pass `ui_setup: None`, call `register_ui_catalog()` **after** `setup`.

## Pieces

1. **Dart definitions** — Flutter `Widget` subclasses (typically
   `StatelessWidget`) annotated with `@LuaWidget`. The **generative constructor
   parameters** are the Lua API. `Key` / `super.key` is skipped. Optional
   `@LuaProperty` / `@LuaCallback` / `@LuaChildren` on ctor params are renames
   only; required/optional comes from nullability and Dart defaults.
2. **Codegen** — add `fluau_codegen` as a **dev_dependency**, then run
   `dart run fluau_codegen` from the app root (paths from
   [`fluau.yaml`](FLUAU_YAML.md) or built-in defaults). Emits a **standalone**
   `widget_serializers.g.dart` under `dart.lua_root` (default `lib/fluau/`) and
   one codegen-owned Rust module `lua_engine.rs` (`setup_lua_api` +
   `register_ui_catalog`). Never hand-roll a Dart registry — use generated
   `LuaWidgetRegistry.buildFromMap`.
3. **Registration** — one place (`#[frb(init)]` / process start). Without
   registration, Rust installs an **empty** `ui` table (plugins crash on
   `ui.Column`, etc.).

### Constructor → Lua names

| Dart | Lua entry |
|------|-----------|
| Unnamed ctor on `@LuaWidget(name: 'Text')` | `ui.Text { ... }` |
| Named ctor `LuaTextWidget.styled(...)` | `ui.Text_styled { ... }` |
| Dotted `@LuaWidget(name: 'layout.column')` | `ui.layout.column { ... }` |

Dotted names nest Rust/`ui` tables and Luau stubs; the JSON `type` id (and
Dart registry key) stays the full string (`"layout.column"`).

### Enums

Host-owned Dart enums on ctor params become Luau string unions **and** an
`enums.<Name>` value table (e.g. `size = enums.TextSize.large`). Wire values
remain strings (`"large"`). Optional `@LuaEnum(name: '…')` renames the Lua
type/table or emits an enum not yet used on a widget.

Flutter / third-party enums cannot be annotated — wrap them in a host preset
(e.g. `CrossAxisAlignmentPreset`) and map in `build`.

### Install

```yaml
dev_dependencies:
  fluau_codegen: ^0.1.11
```

```bash
dart run fluau_codegen
```

Emits `lib/fluau/widget_serializers.g.dart` (or `dart.lua_root`),
`lua_engine.rs` (`setup_lua_api` + `register_ui_catalog`), and `ui.d.luau`.
Codegen also best-effort adds `pub mod lua_engine;` to `lib.rs`. Generated
Rust imports `fluau::mlua` / `fluau::serde_json` — the host only needs the
`fluau` crate (default `runtime`); no separate `mlua` / `serde_json` Cargo
entries for the catalog. It does **not** overwrite stamped `api/fluau.rs`.

### Wire Rust (required one-liner)

```rust
#[flutter_rust_bridge::frb(init)]
pub fn init_app() {
    flutter_rust_bridge::setup_default_user_utils();
    // UI-only (or after setup with ui_setup: None):
    let _ = crate::lua_engine::register_ui_catalog();
}
```

Full app (HostAPIs + UI in one call — skip `register_ui_catalog`):

```rust
fluau::setup(SetupOptions {
    host_apis: vec![/* ... */],
    intent_handlers: vec![],
    constraint_checkers: vec![],
    ui_setup: Some(crate::lua_engine::setup_lua_api),
})?;
```

### Annotate a widget

```dart
@LuaWidget(name: 'Text')
class LuaTextWidget extends StatelessWidget {
  final String text;
  final String? color;

  const LuaTextWidget({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) => Text(text);
}
```

Import the generated registry:

```dart
import 'package:my_app/fluau/widget_serializers.g.dart';

LuaPlugin(
  pluginId: pluginId,
  grants: grants,
  buildWidget: LuaWidgetRegistry.buildFromMap,
);
```

## After adding a widget

Run `./tool/generate.sh`, or `dart run fluau_codegen` from the app root. Only
run `flutter_rust_bridge_codegen generate` if FRB-exposed APIs changed. See
[codegen/WHEN_TO_RUN.md](../codegen/WHEN_TO_RUN.md).
