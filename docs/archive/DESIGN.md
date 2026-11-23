> **Historical / superseded.** This document describes an earlier UserData-over-FFI design. The runtime uses JSON UI snapshots and the current docs under [`docs/`](../). Prefer [Architecture](../ARCHITECTURE.md).

# Lua Flutter Plugin Framework - Design Document

## Overview

This document describes the architecture and design decisions for the Lua Flutter Plugin Framework, which enables runtime UI generation in Flutter apps using Lua scripts executed through Rust.

## Core Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Flutter (Dart)                             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  LuaPlugin Widget                                            ││
│  │    - Executes Lua scripts                                    ││
│  │    - Receives typed LuaWidget from Rust                       ││
│  │    - Converts to Flutter widgets                             ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Widget Converters (Generated)                               ││
│  │    - LuaTextProps → TextProps                                ││
│  │    - LuaTextStyle → TextStyle                                ││
│  │    - LuaWidget enum → Flutter Widget tree                    ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────┬────────────────────────────────────┘
                              │ FFI (flutter_rust_bridge)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Rust + Lua                               │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  LuaWidget Enum (Generated from Dart annotations)            ││
│  │    - Text(LuaTextProps)                                        ││
│  │    - Column(LuaColumnProps)                                   ││
│  │    - ...                                                      ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Lua Types (UserData - Generated)                            ││
│  │    - LuaTextProps { text: String, style: LuaTextStyle }       ││
│  │    - LuaTextStyle { font_size: f64, color: String, ... }     ││
│  │    - LuaColumnProps { children: Vec<LuaWidget>, ... }        ││
│  └─────────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  Lua API (Generated)                                           ││
│  │    - ui.Text { text = "Hello", style = ui.TextStyle {...} }  ││
│  │    - ui.Column { children = { ui.Text {...} } }              ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Design Decisions

### 1. UserData for Type Safety

**Decision**: Use mlua's `UserData` trait to define type-safe Lua types.

**Rationale**:
- Provides compile-time type checking in Lua
- Enables IDE support (Lua Language Server)
- Better error messages for plugin authors
- Matches Flutter's strong typing philosophy

**Implementation**:
```rust
#[derive(UserData)]
struct LuaTextProps {
    text: String,
    style: Option<LuaTextStyle>,
}
```

### 2. Enum for Widget Variants

**Decision**: Use a Rust enum `LuaWidget` to represent all possible widget types.

**Rationale**:
- Type-safe representation of any widget
- Easy to extend with new widget types
- Can be serialized via serde for FFI
- Matches the sealed class pattern in Dart

**Implementation**:
```rust
#[derive(Serialize, Deserialize)]
enum LuaWidget {
    Text(LuaTextProps),
    Column(LuaColumnProps),
    Button(LuaButtonProps),
}
```

### 3. Dart Annotations as Source of Truth

**Decision**: Dart annotations define the widget schema, code generation creates Rust types.

**Rationale**:
- Flutter developers are familiar with Dart
- Easier to test and validate in Dart
- Single language for plugin authors
- Can leverage Dart's type system

**Implementation**:
```dart
@LuaWidget('Text')
class TextLuaWidgetBuilder extends LuaWidgetBuilder<TextProps> {
  @override
  Widget build(BuildContext context, TextProps props) {
    return Text(props.text, style: props.style);
  }
}

@LuaProperties()
class TextProps {
  @LuaProperty(required: true)
  final String text;
  
  @LuaProperty()
  final TextStyle? style;
}
```

### 4. flutter_rust_bridge for FFI

**Decision**: Use flutter_rust_bridge for Rust ↔ Dart communication.

**Rationale**:
- Proven, mature solution
- Handles serialization automatically
- Supports multiple platforms
- Good performance

### 5. Code Generation Pipeline

**Decision**: Two-stage code generation

1. **Stage 1**: Dart code generator creates Rust code from Dart annotations
2. **Stage 2**: flutter_rust_bridge_codegen creates Dart bindings from Rust code

**Rationale**:
- Keeps Dart as the primary language for plugin authors
- Leverages existing tooling (flutter_rust_bridge)
- Clean separation of concerns

## Component Details

### Dart Side

#### 1. Annotation Classes

**File**: `lib/src/lua/annotations.dart`

```dart
/// Marks a class as a Lua widget builder
class LuaWidget {
  final String type;
  const LuaWidget(this.type);
}

/// Marks a class as containing Lua widget properties
class LuaProperties {
  const LuaProperties();
}

/// Annotates a property field
class LuaProperty {
  final bool required;
  final Type? dartType; // For custom type handling
  final String? description;
  
  const LuaProperty({
    this.required = false,
    this.dartType,
    this.description,
  });
}
```

#### 2. Widget Builder Base Class

**File**: `lib/src/lua/widget_builder.dart`

```dart
/// Base class for all Lua widget builders
abstract class LuaWidgetBuilder<T extends LuaProperties> {
  String get type;
  
  /// Parse properties from JSON (generated)
  T parseProperties(Map<String, dynamic> json);
  
  /// Build Flutter widget from typed properties
  Widget build(BuildContext context, T properties);
  
  /// Convenience method for the framework
  Widget buildFromJson(BuildContext context, Map<String, dynamic> json) {
    return build(context, parseProperties(json));
  }
  
  /// Factory
  static final Map<String, LuaWidgetBuilder Function()> _registry = {};
  static LuaWidgetBuilder? create(String type) => _registry[type]?.call();
  
  /// Registration helper
  static void _register(String type, LuaWidgetBuilder Function() factory) {
    _registry[type] = factory;
  }
}
```

#### 3. Generated Converters

**File**: `lib/src/lua/generated/converters.dart` (generated)

```dart
// Generated from LuaTextProps
class LuaTextPropsConverter {
  static TextProps toDart(LuaTextProps luaProps) {
    return TextProps(
      text: luaProps.text,
      style: luaProps.style != null 
          ? LuaTextStyleConverter.toDart(luaProps.style!) 
          : null,
    );
  }
}

class LuaTextStyleConverter {
  static TextStyle toDart(LuaTextStyle luaStyle) {
    return TextStyle(
      fontSize: luaStyle.fontSize,
      color: luaStyle.color != null 
          ? Color(int.parse(luaStyle.color.replaceFirst('#', 'FF'), radix: 16)) 
          : null,
      fontWeight: _parseFontWeight(luaStyle.fontWeight),
    );
  }
}
```

#### 4. LuaPlugin Widget

**File**: `lib/src/lua/lua_plugin.dart`

```dart
import 'package:flutter/material.dart';
import 'package:luatest/src/rust/frb_generated.dart';
import 'widget_builder.dart';
import 'generated/converters.dart';

/// Main widget that executes Lua scripts and renders the result
class LuaPlugin extends StatelessWidget {
  final String luaScript;
  
  const LuaPlugin({super.key, required this.luaScript});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LuaWidget>(
      future: _executeLuaScript(luaScript),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Lua Error: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        
        return snapshot.data!.toFlutterWidget(context);
      },
    );
  }
  
  Future<LuaWidget> _executeLuaScript(String script) async {
    return runLuaUiScript(script: script);
  }
}

/// Convert LuaWidget enum to Flutter widget tree
extension on LuaWidget {
  Widget toFlutterWidget(BuildContext context) {
    if (text != null) {
      final props = LuaTextPropsConverter.toDart(text!);
      return TextLuaWidgetBuilder().build(context, props);
    }
    if (column != null) {
      final props = LuaColumnPropsConverter.toDart(column!);
      return ColumnLuaWidgetBuilder().build(context, props);
    }
    // ... other widget types
    return const SizedBox();
  }
}
```

### Rust Side

#### 1. UserData Types (Generated)

**File**: `rust/src/lua_types.rs` (generated from Dart annotations)

```rust
use mlua::UserData;
use serde::{Serialize, Deserialize};

// Text widget properties
#[derive(Debug, Clone, UserData, Serialize, Deserialize)]
pub struct LuaTextProps {
    pub text: String,
    #[mlua(field)]
    pub style: Option<LuaTextStyle>,
}

// Text style properties
#[derive(Debug, Clone, UserData, Serialize, Deserialize)]
pub struct LuaTextStyle {
    #[mlua(field)]
    pub font_size: Option<f64>,
    #[mlua(field)]
    pub color: Option<String>,
    #[mlua(field)]
    pub font_weight: Option<String>,
}

// Widget enum
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum LuaWidget {
    Text(LuaTextProps),
    Column(LuaColumnProps),
    // ... other widget types
}
```

#### 2. Lua API (Generated)

**File**: `rust/src/lua_api.rs` (generated)

```rust
use mlua::{Lua, Result, UserData};
use crate::lua_types::*;

/// Set up the Lua API with UserData constructors
pub fn setup_lua_api(lua: &Lua) -> Result<()> {
    let ui = lua.create_table()?;
    
    // ui.Text constructor
    ui.set("Text", lua.create_function(|_, props: LuaTextProps| {
        Ok(LuaWidget::Text(props))
    })?)?;
    
    // ui.TextStyle constructor
    ui.set("TextStyle", lua.create_function(|_, ()| {
        Ok(LuaTextStyle {
            font_size: None,
            color: None,
            font_weight: None,
        })
    })?)?;
    
    // ui.Column constructor
    ui.set("Column", lua.create_function(|_, props: LuaColumnProps| {
        Ok(LuaWidget::Column(props))
    })?)?;
    
    // ... other constructors
    
    lua.globals().set("ui", ui)?;
    Ok(())
}

/// Execute a Lua script and return the widget
#[flutter_rust_bridge::frb(sync)]
pub fn run_lua_ui_script(script: String) -> Result<LuaWidget, String> {
    let lua = Lua::new();
    setup_lua_api(&lua).map_err(|e| e.to_string())?;
    
    // Execute script and get LuaWidget
    let result: LuaWidget = lua.load(&script).eval().map_err(|e| e.to_string())?;
    Ok(result)
}
```

#### 3. Module Exports

**File**: `rust/src/lib.rs`

```rust
pub mod lua_api;
pub mod lua_types;
mod frb_generated;
```

**File**: `rust/src/lua_types.rs`
```rust
// Generated UserData types
// ... (see above)
```

## Build Process

### 1. Add Dependencies

**`rust/Cargo.toml`**:
```toml
[dependencies]
flutter_rust_bridge = "=2.12.0"
mlua = { version = "0.10", features = ["luau", "vendored", "serialize"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
```

**`pubspec.yaml`**:
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_rust_bridge: 2.12.0

Dev dependencies:
  build_runner: ^2.4.6
```

### 2. Code Generation Workflow

```bash
# Step 1: Run Dart code generator to create Rust code
flutter pub run build_runner build

# Step 2: Run flutter_rust_bridge_codegen to generate Dart bindings
flutter_rust_bridge_codegen generate

# Step 3: Build the project
flutter pub get
flutter run
```

### 3. Adding a New Widget

1. **Define the Dart builder and properties**:
```dart
@LuaWidget('MyWidget')
class MyWidgetLuaBuilder extends LuaWidgetBuilder<MyWidgetProps> {
  @override
  Widget build(BuildContext context, MyWidgetProps props) {
    return MyFlutterWidget(
      title: props.title,
      icon: props.icon,
    );
  }
}

@LuaProperties()
class MyWidgetProps {
  @LuaProperty(required: true)
  final String title;
  
  @LuaProperty()
  final IconData? icon;
}
```

2. **Run code generators**:
```bash
flutter pub run build_runner build
flutter_rust_bridge_codegen generate
```

3. **Use the new widget in Lua**:
```lua
return ui.MyWidget {
    title = "Hello",
    icon = "icons.add"
}
```

## Error Handling

### Lua Execution Errors
- Caught in Rust and returned as String
- Displayed in Dart with user-friendly messages

### Type Mismatch Errors
- mlua catches type errors when calling UserData constructors
- Returns clear error messages (e.g., "expected TextStyle, got string")

### Missing Required Properties
- Validated by UserData constructors (required fields)
- Can add additional validation in Rust if needed

## Testing

### Unit Tests
- Test individual widget builders
- Test property parsing
- Test error cases

### Integration Tests
- Test complete Lua scripts
- Test nested widgets
- Test all widget types

## Performance Considerations

- **UserData overhead**: Minimal (just pointer indirection)
- **Serialization**: Handled by serde + flutter_rust_bridge
- **Code generation**: Only runs during build, not at runtime

## Future Enhancements

1. **Custom UserData Methods**: Add methods to Lua types (e.g., `text:upper()`)
2. **Hot Reload**: Watch for Lua script changes and reload
3. **State Management**: Add Lua API for state
4. **Callbacks**: Support Lua callbacks for event handlers
5. **Asset Loading**: Load Lua scripts from assets

## File Structure

```
luatest/
├── lib/
│   ├── src/
│   │   ├── lua/
│   │   │   ├── annotations.dart      # @LuaWidget, @LuaProperties, @LuaProperty
│   │   │   ├── widget_builder.dart   # Base LuaWidgetBuilder class
│   │   │   ├── generated/            # Generated converters
│   │   │   │   └── converters.dart
│   │   │   └── lua_plugin.dart       # Main LuaPlugin widget
│   │   └── rust/                     # flutter_rust_bridge bindings
│   │       ├── api/
│   │       │   └── lua.dart
│   │       ├── frb_generated.dart
│   │       ├── frb_generated.io.dart
│   │       └── frb_generated.web.dart
│   └── main.dart
│
├── rust/
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── lua_api.rs               # Lua API with UserData constructors
│       └── lua_types.rs             # Generated UserData types
│
├── flutter_rust_bridge.yaml
├── build.yaml
└── DESIGN.md
```

## Summary

This architecture provides:
- ✅ **Type safety** in Lua, Rust, and Dart
- ✅ **Single source of truth** (Dart annotations)
- ✅ **Code generation** for all boilerplate
- ✅ **Clean API** for plugin authors
- ✅ **Production-ready** scalability
- ✅ **Good performance**

The UserData approach with code generation creates a robust, maintainable framework that plugin authors will love to use.
