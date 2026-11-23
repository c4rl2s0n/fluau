# Lua Plugin Codegen Overview

This document explains how code generation and Luau stubs work for the Lua Flutter Plugin framework.

## Inventory: what is generated

| Artifact | Source of truth | How it updates |
|----------|-----------------|----------------|
| `assets/plugins/_types/ui.d.luau` | Dart `@LuaWidget` under `lib/lua/widgets/` | [`./tool/generate.sh`](tool/generate.sh) (Dart CLI) |
| `lib/lua/widgets/widget_serializers.g.dart` | same | same |
| `rust/src/lua_engine.rs` (+ `api/lua.rs`) | same | same |
| `assets/plugins/_types/host.d.luau` | Rust host traits under `rust/src/host/` | **Automatic** via [`rust/build.rs`](rust/build.rs) on every `cargo build` / Flutter cargokit build; also via `./tool/generate.sh` |
| `assets/plugins/_types/plugin.d.luau` | Plugin lifecycle / intent shapes | **Hand-maintained** |
| FRB bindings | Rust `#[frb]` | `flutter_rust_bridge_codegen generate` when the FFI surface changes |

**Not `build_runner`.** Widget/host catalog codegen is a custom Dart tool in [`tool/codegen`](tool/codegen) (kept out of the root `pubspec.yaml` to avoid analyzer conflicts) plus Rust `build.rs` for host stubs. Do not add `build_runner` for this pipeline.

**One command for developers:**

```bash
./tool/generate.sh          # widgets + host stubs
./tool/check_generated.sh   # regenerate and fail if git diff is dirty
```

Widget outputs are **committed inputs** to the Rust compile (`lua_engine.rs`). They cannot be produced by Cargo `build.rs` without circular coupling. Host stubs *can* and do refresh on every Cargo/Flutter native build.

## Widget codegen architecture

```
Dart Source Files
    │
    ▼
[@LuaWidget] Annotations on Dart classes
    │
    ▼
AnnotationParser (analyzer 14.x)
    │
    ▼
LuaClassInfo / PropertyInfo models
    │
    ▼
┌──────────────────┬──────────────────┬──────────────────┐
│ DartGenerator     │ RustGenerator     │ LuauStubGenerator │
│ (Dart serializers)│ (Lua API bindings)│ (luau-lsp stubs)  │
└─────────┬─────────┴─────────┬─────────┴─────────┬────────┘
          │                   │                   │
          ▼                   ▼                   ▼
Dart: widget_serializers.g.dart
Rust: lua_engine.rs + api/lua.rs
Luau: assets/plugins/_types/ui.d.luau
```

## Widget codegen flow

### 1. CLI Entry Point

Prefer the repo script:

```bash
./tool/generate.sh
```

Or invoke the CLI directly:

```bash
cd tool/codegen && dart pub get
dart run bin/lua_plugin_codegen.dart --generate \
  --input ../../lib/lua/widgets \
  --rust-out ../../rust/src \
  --dart-out ../../lib/lua/widgets \
  --luau-out ../../assets/plugins/_types
```

### 2. Annotation Parser

Uses `analyzer` 14.x to parse Dart files and extract annotated classes.

**Key changes for analyzer 14:**
- `LibraryElement.definingCompilationUnit` removed → use `LibraryElement.classes/enums/topLevelFunctions/topLevelVariables` directly
- `Element.metadata` is a `Metadata` object → use `metadata.annotations` (returns `List<ElementAnnotation>`)
- `Element.name` is `String?` (nullable) → add null checks
- `DartType.element` is `Element?` (nullable) → use null-aware operators where needed

### 3. Dart Serializer Generator

Generates strongly-typed `fromJson()` methods for each Lua widget class.

**Example generated code:**
```dart
// widget_serializers.g.dart
extension _LuaTextWidgetSerializer on LuaTextWidget {
  static LuaTextWidget fromJson(Map<String, dynamic> json) {
    return LuaTextWidget(
      text: json['text'] as String,
      size: json['size'] != null ? _parseTextSize(json['size'] as String?) : null,
      color: json['color'] != null ? _parseTextColor(json['color'] as String?) : null,
      weight: json['weight'] != null ? _parseFontWeightPreset(json['weight'] as String?) : null,
    );
  }
}

// Enum parsers
TextSize? _parseTextSize(String? value) {
  if (value == null) return null;
  switch (value) {
    case 'small': return TextSize.small;
    case 'medium': return TextSize.medium;
    case 'large': return TextSize.large;
    default: throw FormatException('Unknown TextSize value: $value');
  }
}

// Widget registry
class LuaWidgetRegistry {
  static final Map<String, LuaWidgetInterface Function(Map<String, dynamic>)> _builders = {
    'Column': (json) => _LuaColumnWidgetSerializer.fromJson(json),
    'Button': (json) => _LuaButtonWidgetSerializer.fromJson(json),
    'Text': (json) => _LuaTextWidgetSerializer.fromJson(json),
  };
  
  static Widget buildFromMap(BuildContext context, Map<String, dynamic> widgetMap) {
    final widgetType = widgetMap['type'] as String?;
    final properties = Map<String, dynamic>.from(widgetMap);
    properties.remove('type');
    final widget = fromJson(widgetType, properties);
    return widget.build(context);
  }
}
```

### 4. Rust Generator

Generates Lua API bindings that construct JSON-serializable tables.

**Example generated code:**
```rust
// lua_engine.rs
pub fn setup_lua_api(lua: &Lua) -> Result<()> {
    let ui = lua.create_table()?;
    
    // ui.Text constructor
    ui.set("Text", lua.create_function(|lua, args: Table| -> Result<Value> {
        let mut map = JsonMap::new();
        map.insert("type".to_string(), json!("Text"));
        
        let text: String = args.get("text")?;
        map.insert("text".to_string(), json!(text));
        
        // Validate enum
        let size: Option<String> = args.get("size").ok();
        if let Some(ref v) = size {
            if !["small", "medium", "large"].contains(&v.as_str()) {
                return Err(mlua::Error::runtime("Text: invalid size value"));
            }
            map.insert("size".to_string(), json!(v));
        }
        
        let json_str = serde_json::to_string(&map)?;
        Ok(Value::String(lua.create_string(&json_str)?))
    })?)?;
    
    // State management
    ui.set("getState", lua.create_function(|_, key: String| {
        crate::state::get_state(&key).map_err(|e| mlua::Error::runtime(e))
    })?)?;
    
    lua.globals().set("ui", ui)?;
    Ok(())
}

pub fn execute_ui_script(script: &str) -> std::result::Result<String, String> {
    let lua = Lua::new();
    setup_lua_api(&lua)?;
    let result: Value = lua.load(script).eval()?;
    let result_str = match result {
        Value::String(s) => s.to_string_lossy().to_owned(),
        _ => return Err("Lua script must return a widget (string)".to_string()),
    };
    Ok(result_str)
}
```

### 5. Luau Stub Generator (widgets)

Emits `assets/plugins/_types/ui.d.luau` for luau-lsp: enum string unions, per-widget props tables, and a `declare ui` catalog.

### 6. Host API stubs (Rust build.rs)

Host modules are annotated traits (`#[host_module]`, `#[lua]`, `HostType`, `HostUserData`) under `rust/src/host/`. On every `cargo build` of `rust_lib_luatest`, [`rust/build.rs`](rust/build.rs) runs `host_api_meta` and regenerates `assets/plugins/_types/host.d.luau`.

| Layer | Mechanism |
|-------|-----------|
| Widgets + `ui.d.luau` | Dart annotations → [`tool/codegen`](tool/codegen) / [`./tool/generate.sh`](tool/generate.sh) |
| Host + `host.d.luau` | Rust traits/UserData → Cargo `build.rs` (also run by `./tool/generate.sh`) |
| Lifecycle intents | `plugin.d.luau` hand-maintained |

To verify committed outputs are fresh: [`./tool/check_generated.sh`](tool/check_generated.sh).

## Type Support

| Dart Type | Rust Type | Lua Type | Handling |
|-----------|-----------|----------|----------|
| `String` | `String` | `string` | Direct |
| `int` | `i64` | `integer` | Direct |
| `double` | `f64` | `number` | Direct |
| `bool` | `bool` | `boolean` | Direct |
| `Enum` | `String` | `string` | Validated against enum values |
| `LuaWidgetInterface` | N/A | `table` | Recursive widget |
| `List<LuaWidgetInterface>` | N/A | `table` | Recursive list |
| `@LuaCallback` | `String` (ID) | `function` | Callback registry |

## Design Decisions

### JSON as the Bridge
- Rust returns JSON strings (not complex UserData/trait objects)
- Avoids mlua 0.10 UserData complexity
- FFI is simple: just pass strings
- Dart uses codegen for type-safe deserialization

### Strong Typing
- No `Map<String, dynamic>` in widget construction
- All property access is type-safe via codegen
- Enum values validated at Lua runtime

### Codegen Strategy
- **Dart**: Generates `fromJson()` that creates widget instances
- **Rust**: Generates Lua constructors that build JSON tables
- **Bridge**: JSON strings through FFI

## Usage Example

### 1. Define Dart Widget

```dart
@LuaWidget()
class LuaTextWidget implements LuaWidgetInterface {
  final String text;
  final TextSize? size;
  final TextColor? color;
  final FontWeightPreset? weight;
  
  const LuaTextWidget({
    required this.text,
    this.size,
    this.color,
    this.weight,
  });
  
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: size?.value,
        color: color?.toColor(),
        fontWeight: weight?.toFontWeight(),
      ),
    );
  }
}
```

### 2. Write Lua Script

```lua
return ui.Text {
  text = "Hello from Lua!",
  size = "large",
  color = "primary",
  weight = "bold"
}
```

### 3. Flow

```
Lua: ui.Text { text = "Hello", size = "large" }
  ↓
Rust (mlua): Validates enum, builds JSON table
  ↓
JSON: {"type": "Text", "text": "Hello", "size": "large"}
  ↓
Dart (codegen): _LuaTextWidgetSerializer.fromJson() → LuaTextWidget
  ↓
Flutter: LuaTextWidget.build(context) → Text widget
  ↓
Rendered UI
```

## File Structure

```
luatest/
├── lib/
│   └── lua/
│       ├── widgets/
│       │   ├── widget.dart           # LuaWidgetInterface, LuaWidgetRegistry
│       │   ├── text.dart             # LuaTextWidget
│       │   ├── button.dart           # LuaButtonWidget
│       │   ├── column.dart           # LuaColumnWidget
│       │   └── widget_serializers.g.dart  # Generated
│       └── annotations.dart          # @LuaWidget, @LuaProperty, etc.
└── tool/
    └── codegen/
        ├── pubspec.yaml
        └── lib/
            ├── codegen.dart          # CLI
            ├── models/widget_info.dart
            ├── parsers/annotation_parser.dart
            └── generators/
                ├── rust_generator.dart
                ├── dart_serializer_generator.dart
                └── luau_stub_generator.dart
```

## Annotations

### Class Annotations

```dart
@LuaWidget(name: 'CustomName', hasChildren: true)
class MyWidget { ... }

@LuaData(name: 'CustomType')
class MyData { ... }
```

### Property Annotations

```dart
@LuaProperty(required: true, defaultValue: 'default')
String myProperty;

@LuaChildren()
List<LuaWidgetInterface> children;

@LuaCallback()
String? onPressed;  // Stored as callback ID
```

## Running Codegen

```bash
# From project root — preferred
./tool/generate.sh
./tool/check_generated.sh   # optional freshness check

# Or call the Dart CLI directly (see Widget codegen flow above)
```

## Dependencies (codegen tool)

```yaml
dependencies:
  analyzer: ^14.1.0
  build: ^4.0.10
  source_gen: ^4.2.4
  code_builder: ^4.4.0
  dart_style: ^3.1.12
  path: ^1.8.0
  yaml: ^3.1.0
```
