# Lua Flutter Plugin Framework - Refined Plan

## Overview

**Goal**: Build a framework for creating runtime plugins to extend Flutter apps using Lua scripts, with a code generation system to eliminate manual boilerplate.

**Architecture Decision**: 
- Lua widget classes are **dataclasses** (not extending StatelessWidget)
- Each Lua widget implements `LuaWidgetInterface` with a `build(BuildContext context)` method
- Widget properties are annotated with `@LuaProperty`, `@LuaChildren`, or `@LuaCallback`
- Codegen generates strongly typed JSON serializers/deserializers
- Codegen generates Rust UserData structs and Lua API bindings
- No `Map<String, dynamic>` passed around in user code - everything is strongly typed

**Key Design Points**:
- Limited widget catalog (no full Flutter API exposure)
- Enum properties for style presets (not full TextStyle, etc.)
- Strong typing throughout
- Secure Lua execution via mlua with Luau sandboxing

---

## Architecture Overview

### Data Flow

```
Lua Script (ui.Text { text = "Hello", size = "large" })
    ↓
Rust Lua Engine (mlua)
    ↓
Rust UserData Structs (strongly typed)
    ↓
JSON Serialization
    ↓
Dart JSON Deserialization (codegen)
    ↓
LuaWidgetInterface instances (strongly typed dataclasses)
    ↓
Flutter Widget Tree (via build() method)
    ↓
Rendered UI
```

### Component Layers

1. **Lua Script Layer**: Lua scripts define widget trees using `ui.WidgetName { ... }` syntax
2. **Rust Layer**: Lua execution engine with mlua, UserData structs, JSON serialization
3. **FFI Layer**: flutter_rust_bridge for Dart-Rust communication
4. **Dart Layer**: Codegen serializers, widget registry, LuaWidgetInterface implementations
5. **Flutter Layer**: Actual Flutter widgets rendered from Lua definitions

---

## Current State Analysis

### What's Working
- Annotation system (`@LuaWidget`, `@LuaProperty`, `@LuaChildren`, `@LuaCallback`)
- Code generator CLI with parser
- Widget dataclasses (LuaTextWidget, LuaButtonWidget, LuaColumnWidget)
- LuaWidgetInterface base interface
- LuaWidgetRegistry with codegen serializers
- Enum type support (TextSize, TextColor, FontWeightPreset, etc.)
- Nested widget support (Column children, Button child)
- Callback support (Button onPressed)

### Issues to Fix
1. **Generated Dart serializers**: `_deserializeWidget` doesn't have access to BuildContext
2. **Generated Dart serializers**: `_deserializeWidgetList` needs to handle widget list deserialization
3. **Rust code generation**: Need to implement (currently only Dart serializers generated)
4. **Rust Lua API**: Need to set up mlua with proper widget constructors
5. **State management**: Need to implement in Rust
6. **Callbacks**: Need to implement callback registry in Rust
7. **FFI integration**: Need to wire up flutter_rust_bridge

### Files to Create/Update
- [x] `lib/lua/annotations.dart` - Annotation classes
- [x] `lib/lua/types.dart` - Enum type definitions
- [x] `lib/lua/widgets/widget.dart` - LuaWidgetInterface, LuaWidgetRegistry
- [x] `lib/lua/widgets/text.dart` - LuaTextWidget
- [x] `lib/lua/widgets/button.dart` - LuaButtonWidget
- [x] `lib/lua/widgets/column.dart` - LuaColumnWidget
- [ ] `tool/codegen/lib/models/widget_info.dart` - Parse @LuaChildren annotation
- [ ] `tool/codegen/lib/parsers/annotation_parser.dart` - Handle @LuaChildren
- [ ] `tool/codegen/lib/generators/dart_serializer_generator.dart` - Fix child widget deserialization
- [ ] `tool/codegen/lib/generators/rust_generator.dart` - Generate proper Rust code
- [ ] `rust/src/lua_engine.rs` - Lua execution with widget constructors
- [ ] `rust/src/api/lua.rs` - FFI API functions
- [ ] `rust/src/state.rs` - State management
- [ ] `rust/src/callbacks.rs` - Callback registry
- [ ] `lib/lua/lua_plugin.dart` - Main widget with FFI calls
- [ ] `lib/main.dart` - Demo app

---

## Refined Implementation Plan

### Phase 1: Fix Dart Code Generation (PRIORITY)

#### 1.1 Fix Child Widget Deserialization in Generated Serializers

**Problem**: The generated `_deserializeWidget` function doesn't have access to BuildContext, and `_deserializeWidgetList` doesn't properly handle nested widget deserialization.

**Solution**: 
- Generate serializers that create widget instances (not build them immediately)
- The LuaWidgetRegistry handles the build() call with proper context
- For child widgets, generate recursive deserialization

**Files**:
- `tool/codegen/lib/generators/dart_serializer_generator.dart`

**Expected Generated Code** for LuaColumnWidget:
```dart
extension _LuaColumnWidgetSerializer on LuaColumnWidget {
  static LuaColumnWidget fromJson(Map<String, dynamic> json) {
    return LuaColumnWidget(
      spacing: json['spacing'] != null ? json['spacing'] as double : null,
      mainAxisAlignment: json['mainAxisAlignment'] != null 
          ? _parseMainAxisAlignmentPreset(json['mainAxisAlignment'] as String?) 
          : null,
      crossAxisAlignment: json['crossAxisAlignment'] != null 
          ? _parseCrossAxisAlignmentPreset(json['crossAxisAlignment'] as String?) 
          : null,
      children: json['children'] != null 
          ? (json['children'] as List<dynamic>).map((c) => _deserializeLuaWidget(c as Map<String, dynamic>)).toList()
          : null,
    );
  }
}

// Helper to deserialize any Lua widget
LuaWidgetInterface _deserializeLuaWidget(Map<String, dynamic> json) {
  final type = json['type'] as String?;
  if (type == null) return const LuaEmptyWidget();
  
  final properties = Map<String, dynamic>.from(json);
  properties.remove('type');
  
  switch (type) {
    case 'Text':
      return _LuaTextWidgetSerializer.fromJson(properties);
    case 'Button':
      return _LuaButtonWidgetSerializer.fromJson(properties);
    case 'Column':
      return _LuaColumnWidgetSerializer.fromJson(properties);
    default:
      return const LuaEmptyWidget();
  }
}
```

#### 1.2 Parse @LuaChildren Annotation

**Problem**: The annotation parser needs to identify @LuaChildren annotated properties to handle them differently.

**Files**:
- `tool/codegen/lib/parsers/annotation_parser.dart`
- `tool/codegen/lib/models/widget_info.dart`

**Changes**:
- Add `isChildList` flag to PropertyInfo
- Identify @LuaChildren annotation in parser
- Set isChildList = true for properties with @LuaChildren

#### 1.3 Handle @LuaCallback Annotation

**Problem**: @LuaCallback properties need special handling (stored as String callback IDs).

**Files**:
- `tool/codegen/lib/models/widget_info.dart`
- `tool/codegen/lib/generators/dart_serializer_generator.dart`

**Changes**:
- Add `isCallback` flag to PropertyInfo (already exists)
- Generate callback ID handling in serializers

---

### Phase 2: Rust Code Generation

#### 2.1 Generate Rust UserData Structs

**Files**:
- `tool/codegen/lib/generators/rust_generator.dart`

**For each widget class**, generate:
```rust
#[derive(Debug, Clone, UserData)]
pub struct LuaText {
    pub text: String,
    pub size: Option<TextSize>,
    pub color: Option<TextColor>,
    pub weight: Option<FontWeightPreset>,
}

impl LuaWidget for LuaText {
    fn widget_type(&self) -> &'static str {
        "Text"
    }
    
    fn to_json(&self) -> serde_json::Value {
        serde_json::json!({
            "type": self.widget_type(),
            "text": self.text,
            "size": self.size.map(|s| s.to_string()),
            "color": self.color.map(|c| c.to_string()),
            "weight": self.weight.map(|w| w.to_string()),
        })
    }
}
```

**For enums**, generate:
```rust
#[derive(Debug, Clone, UserData, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TextSize {
    Small,
    Medium,
    Large,
}

impl std::fmt::Display for TextSize {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TextSize::Small => write!(f, "small"),
            TextSize::Medium => write!(f, "medium"),
            TextSize::Large => write!(f, "large"),
        }
    }
}

impl From<String> for TextSize {
    fn from(s: String) -> Self {
        match s.as_str() {
            "small" => TextSize::Small,
            "medium" => TextSize::Medium,
            "large" => TextSize::Large,
            _ => TextSize::Medium,
        }
    }
}
```

#### 2.2 Generate Lua API Setup

**Files**:
- `tool/codegen/lib/generators/rust_generator.dart`

**Generate**:
```rust
pub fn setup_lua_api(lua: &Lua) -> Result<()> {
    let ui = lua.create_table()?;
    
    // ui.Text constructor
    ui.set("Text", lua.create_function(|lua, args: Table| -> Result<Box<dyn LuaWidget>> {
        let text: String = args.get("text")?.ok_or_else(|| mlua::Error::runtime("Text: missing required property 'text'"))??;
        
        let size: Option<TextSize> = args.get("size")?;
        let color: Option<TextColor> = args.get("color")?;
        let weight: Option<FontWeightPreset> = args.get("weight")?;
        
        // Process children if any (for Column, etc.)
        // For Text, no children
        
        Ok(Box::new(LuaText {
            text,
            size,
            color,
            weight,
        }))
    })?)?;
    
    // ui.Button constructor
    ui.set("Button", lua.create_function(|lua, args: Table| -> Result<Box<dyn LuaWidget>> {
        let text: Option<String> = args.get("text")?;
        let on_pressed: Option<Function> = args.get("onPressed")?;
        
        // Convert function to callback ID
        let on_pressed_id: Option<String> = on_pressed.map(|f| {
            CALLBACKS.register(lua, f).unwrap()
        });
        
        let child: Option<Box<dyn LuaWidget>> = args.get("child")?;
        
        Ok(Box::new(LuaButton {
            text,
            on_pressed: on_pressed_id,
            child,
        }))
    })?)?;
    
    // ui.Column constructor
    ui.set("Column", lua.create_function(|lua, args: Table| -> Result<Box<dyn LuaWidget>> {
        let spacing: Option<f64> = args.get("spacing")?;
        let main_axis_alignment: Option<MainAxisAlignmentPreset> = args.get("mainAxisAlignment")?;
        let cross_axis_alignment: Option<CrossAxisAlignmentPreset> = args.get("crossAxisAlignment")?;
        
        // Handle children list
        let children: Vec<Box<dyn LuaWidget>> = args.get("children")
            .and_then(|v: Value| v.into_table().ok())
            .map(|t: Table| {
                t.iter()
                    .filter_map(|(_, v)| v.into_userdata::<Box<dyn LuaWidget>>().ok())
                    .collect()
            })
            .unwrap_or_default();
        
        Ok(Box::new(LuaColumn {
            spacing,
            main_axis_alignment,
            cross_axis_alignment,
            children,
        }))
    })?)?;
    
    // State management
    ui.set("getState", lua.create_function(|_, key: String| {
        Ok(state::get_state(&key)?)
    })?)?;
    
    ui.set("setState", lua.create_function(|_, (key, value): (String, String)| {
        Ok(state::set_state(key, value)?)
    })?)?;
    
    // Callback registration
    ui.set("registerCallback", lua.create_function(|lua, func: Function| {
        Ok(callbacks::register_callback(lua, func)?)
    })?)?;
    
    lua.globals().set("ui", ui)?;
    Ok(())
}
```

#### 2.3 Generate LuaWidget Trait

```rust
pub trait LuaWidget: UserData + Send + Sync {
    fn widget_type(&self) -> &'static str;
    fn to_json(&self) -> serde_json::Value;
}

// For child widget lists
pub struct LuaWidgetList {
    pub widgets: Vec<Box<dyn LuaWidget>>,
}

impl UserData for LuaWidgetList {
    // Implementation
}
```

#### 2.4 Generate Main Lua Engine Module

```rust
pub fn execute_ui_script(script: &str) -> Result<String, String> {
    let lua = Lua::new();
    setup_lua_api(&lua).map_err(|e| e.to_string())?;
    
    // Execute the script - should return a Box<dyn LuaWidget>
    let result: Box<dyn LuaWidget> = lua.load(script)
        .eval()
        .map_err(|e| e.to_string())?;
    
    // Convert to JSON
    let json = result.to_json();
    Ok(json.to_string())
}
```

---

### Phase 3: Rust Implementation

#### 3.1 Update/Finish Rust Lua Engine

**File**: `rust/src/lua_engine.rs`

- Implement LuaWidget trait
- Implement UserData for all generated widget structs
- Implement setup_lua_api function
- Implement execute_ui_script function

#### 3.2 Implement State Management

**File**: `rust/src/state.rs`

```rust
use std::collections::HashMap;
use std::sync::{RwLock, Arc};
use serde_json::{Value, json};

#[derive(Debug, Default)]
pub struct LuaStateStore {
    state: Arc<RwLock<HashMap<String, Value>>>,
}

impl LuaStateStore {
    pub fn new() -> Self {
        Self {
            state: Arc::new(RwLock::new(HashMap::new())),
        }
    }
    
    pub fn get(&self, key: &str) -> Option<Value> {
        let state = self.state.read().unwrap();
        state.get(key).cloned()
    }
    
    pub fn set(&self, key: String, value: Value) {
        let mut state = self.state.write().unwrap();
        state.insert(key, value);
    }
    
    pub fn get_all(&self) -> Value {
        let state = self.state.read().unwrap();
        json!(state.iter().collect::<HashMap<_, _>>())
    }
}

lazy_static::lazy_static! {
    pub static ref STATE: LuaStateStore = LuaStateStore::new();
}

pub fn get_state(key: &str) -> Result<String, String> {
    STATE.get(key)
        .map(|v| v.to_string())
        .ok_or_else(|| format!("State key '{}' not found", key))
}

pub fn set_state(key: String, value: String) -> Result<(), String> {
    let json_value: Value = serde_json::from_str(&value)
        .map_err(|e| format!("Invalid JSON: {}", e))?;
    STATE.set(key, json_value);
    Ok(())
}

pub fn get_all_state() -> Result<String, String> {
    Ok(STATE.get_all().to_string())
}
```

#### 3.3 Implement Callback Registry

**File**: `rust/src/callbacks.rs`

```rust
use mlua::{Lua, Result, RegistryKey, Thread, Function};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Default)]
pub struct CallbackRegistry {
    callbacks: Arc<Mutex<HashMap<String, (RegistryKey, Thread)>>>,
}

impl CallbackRegistry {
    pub fn new() -> Self {
        Self {
            callbacks: Arc::new(Mutex::new(HashMap::new())),
        }
    }
    
    pub fn register(&self, lua: &Lua, func: Function) -> Result<String> {
        let registry_key = lua.create_registry_value(func)?;
        let id = Uuid::new_v4().to_string();
        
        let mut callbacks = self.callbacks.lock().unwrap();
        callbacks.insert(id.clone(), (registry_key, lua.create_thread(
            lua.load("return function(...) return ... end").into_function()?
        )?));
        
        Ok(id)
    }
    
    pub fn execute(&self, lua: &Lua, id: &str, args: Vec<mlua::Value>) -> Result<mlua::Value> {
        let callbacks = self.callbacks.lock().unwrap();
        let (registry_key, _) = callbacks.get(id)
            .ok_or_else(|| mlua::Error::runtime(format!("Callback {} not found", id)))?;
        
        let func: Function = lua.registry_value(registry_key)?;
        func.call::<_, mlua::Value>(args)
    }
    
    pub fn remove(&self, id: &str) -> bool {
        let mut callbacks = self.callbacks.lock().unwrap();
        callbacks.remove(id).is_some()
    }
}

lazy_static::lazy_static! {
    pub static ref CALLBACKS: CallbackRegistry = CallbackRegistry::new();
}

pub fn register_callback(lua: &Lua, func: Function) -> Result<String> {
    CALLBACKS.register(lua, func)
}

pub fn execute_callback(id: String) -> Result<String, String> {
    let lua = Lua::new();
    let result = CALLBACKS.execute(&lua, &id, vec![])
        .map_err(|e| e.to_string())?;
    Ok(result.to_string())
}
```

#### 3.4 Create API Bindings

**File**: `rust/src/api/lua.rs`

```rust
use flutter_rust_bridge::frb;

#[frb(sync)]
pub fn run_lua_ui_script(script: String) -> Result<String, String> {
    crate::lua_engine::execute_ui_script(&script)
}

#[frb(sync)]
pub fn get_lua_state(key: String) -> Result<String, String> {
    crate::state::get_state(&key)
}

#[frb(sync)]
pub fn set_lua_state(key: String, value: String) -> Result<(), String> {
    crate::state::set_state(key, value)
}

#[frb(sync)]
pub fn get_all_lua_state() -> Result<String, String> {
    crate::state::get_all_state()
}

#[frb(sync)]
pub fn execute_lua_callback(callback_id: String) -> Result<String, String> {
    crate::callbacks::execute_callback(callback_id)
}
```

#### 3.5 Update Cargo.toml

Ensure dependencies are present:
```toml
[dependencies]
mlua = { version = "0.10", features = ["lua54", "vendored", "luau"] }
serde = { version = "1.0", features = ["derive"] }
serde_json = "1.0"
flutter_rust_bridge = "2.0"
lazy_static = "1.4"
uuid = { version = "1.0", features = ["v4"] }
```

#### 3.6 Update lib.rs

```rust
pub mod api;
mod frb_generated;
pub mod lua_engine;
pub mod state;
pub mod callbacks;
pub mod widgets;

pub use widgets::*;
```

---

### Phase 4: Dart Integration

#### 4.1 Update LuaWidgetRegistry

**File**: `lib/lua/widgets/widget.dart`

- Ensure the registry properly handles widget deserialization
- Fix the `_deserializeWidget` function to work without BuildContext

**Updated Code**:
```dart
/// Registry for deserializing Lua widgets from JSON
class LuaWidgetRegistry {
  /// Map of widget type names to their deserialization functions
  static final Map<String, LuaWidgetInterface Function(Map<String, dynamic>)> _builders = {};
  
  /// Register a widget builder for a type
  static void register(String type, LuaWidgetInterface Function(Map<String, dynamic>) builder) {
    _builders[type] = builder;
  }
  
  /// Deserialize a widget from JSON (without building it)
  static LuaWidgetInterface fromJson(String type, Map<String, dynamic> json) {
    final builder = _builders[type];
    if (builder != null) {
      return builder(json);
    }
    return const LuaEmptyWidget();
  }
  
  /// Build a widget from a full widget map (including type field)
  static Widget buildFromMap(BuildContext context, Map<String, dynamic> widgetMap) {
    final widgetType = widgetMap['type'] as String?;
    
    if (widgetType == null) {
      return const LuaEmptyWidget();
    }
    
    // Remove 'type' from properties
    final properties = Map<String, dynamic>.from(widgetMap);
    properties.remove('type');
    
    // Deserialize and build
    final widget = fromJson(widgetType, properties);
    return widget.build(context);
  }
}

// Helper to deserialize any Lua widget
LuaWidgetInterface _deserializeLuaWidget(Map<String, dynamic> json) {
  final type = json['type'] as String?;
  if (type == null) return const LuaEmptyWidget();
  
  final properties = Map<String, dynamic>.from(json);
  properties.remove('type');
  
  return LuaWidgetRegistry.fromJson(type, properties);
}
```

#### 4.2 Update LuaPlugin Widget

**File**: `lib/lua/lua_plugin.dart`

```dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:luatest/src/rust/frb_generated.dart';
import 'widgets/widget.dart';

/// Main widget that executes a Lua script and renders the resulting UI
class LuaPlugin extends StatelessWidget {
  final String luaScript;
  final Map<String, dynamic>? initialState;
  
  const LuaPlugin({
    super.key,
    required this.luaScript,
    this.initialState,
  });
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _executeLuaScript(),
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
        
        try {
          final widgetMap = jsonDecode(snapshot.data!) as Map<String, dynamic>;
          return LuaWidgetRegistry.buildFromMap(context, widgetMap);
        } catch (e) {
          return Center(
            child: Text(
              'Parse Error: $e',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
      },
    );
  }
  
  Future<String> _executeLuaScript() async {
    // Initialize state if provided
    if (initialState != null) {
      for (final entry in initialState!.entries) {
        await RustLib.instance.api.setLuaState(
          key: entry.key,
          value: jsonEncode(entry.value),
        );
      }
    }
    
    return RustLib.instance.api.runLuaUiScript(script: luaScript);
  }
}
```

#### 4.3 Update Callback Execution in Button

**File**: `lib/lua/widgets/button.dart`

```dart
// Update _executeLuaCallback method
Future<void> _executeLuaCallback(String callbackId) async {
  try {
    await RustLib.instance.api.executeLuaCallback(callbackId: callbackId);
  } catch (e) {
    debugPrint('Lua callback error: $e');
  }
}
```

---

### Phase 5: Testing & Polish

#### 5.1 Test Generated Code

Run the code generator:
```bash
cd /home/ikusa/workspace/Flutter/luatest
flutter pub run lua_plugin_codegen --generate \
  --input lib/lua/widgets \
  --rust-out rust/src \
  --dart-out lib/lua/widgets
```

Verify:
- Dart serializers compile
- Rust code compiles with `cargo check`

#### 5.2 Test End-to-End

Update `lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:luatest/src/rust/frb_generated.dart';
import 'lua/lua_plugin.dart';

Future<void> main() async {
  await RustLib.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Lua Plugin Demo')),
        body: Center(
          child: LuaPlugin(
            luaScript: '''
              return ui.Column {
                spacing = 16,
                mainAxisAlignment = "center",
                children = {
                  ui.Text {
                    text = "Hello from Lua!",
                    size = "large",
                    color = "primary",
                    weight = "bold"
                  },
                  ui.Button {
                    text = "Click me!",
                    onPressed = function()
                      ui.setState("count", tostring(tonumber(ui.getState("count") or "0") + 1))
                    end
                  }
                }
              }
            ''',
            initialState: {'count': '0'},
          ),
        ),
      ),
    );
  }
}
```

#### 5.3 Add More Widgets

- Row
- Container
- SizedBox
- Padding
- Center
- Expanded
- Icon
- Divider
- TextField (limited)
- Image (limited)

#### 5.4 Add Tests

- Dart widget tests
- Rust unit tests
- Integration tests

#### 5.5 Documentation

- Lua API documentation
- Widget catalog documentation
- Code generation documentation

---

## Todo List

### Priority 1: Dart Code Generation Fixes
- [ ] Fix dart_serializer_generator.dart to handle child widget deserialization
- [ ] Parse @LuaChildren annotation properly
- [ ] Handle @LuaCallback properties in serializers
- [ ] Update widget.dart registry to work with new serializers
- [ ] Test Dart code generation

### Priority 2: Rust Code Generation
- [ ] Update rust_generator.dart to generate proper UserData structs
- [ ] Generate LuaWidget trait implementation
- [ ] Generate Lua API setup with widget constructors
- [ ] Generate execute_ui_script function
- [ ] Handle enum types in Rust generation
- [ ] Handle child widgets in Rust generation
- [ ] Handle callback properties in Rust generation

### Priority 3: Rust Implementation
- [ ] Create/update rust/src/lua_engine.rs
- [ ] Create rust/src/state.rs
- [ ] Create rust/src/callbacks.rs
- [ ] Create rust/src/api/lua.rs
- [ ] Update rust/Cargo.toml
- [ ] Update rust/src/lib.rs
- [ ] Test Rust compilation

### Priority 4: Dart Integration
- [ ] Update LuaPlugin widget with FFI calls
- [ ] Update button callback execution
- [ ] Test end-to-end flow

### Priority 5: Testing & Polish
- [ ] Run code generator and verify output
- [ ] Test with demo app
- [ ] Add more widget types
- [ ] Add error handling
- [ ] Add tests
- [ ] Add documentation

---

## Success Criteria

✅ Dart code generation produces valid, compiling code
✅ Rust code generation produces valid, compiling code
✅ Lua scripts can create widget trees
✅ Widget trees are rendered correctly in Flutter
✅ State management works between Lua and Dart
✅ Callbacks work from Lua to Dart/Rust
✅ All tests pass

---

## Files Structure (Final)

```
luatest/
├── lib/
│   ├── lua/
│   │   ├── annotations.dart          # @LuaWidget, @LuaProperty, @LuaChildren, @LuaCallback
│   │   ├── types.dart                # Enum type definitions
│   │   ├── lua_plugin.dart           # Main LuaPlugin widget
│   │   └── widgets/
│   │       ├── widget.dart           # LuaWidgetInterface, LuaWidgetRegistry, LuaEmptyWidget
│   │       ├── text.dart             # LuaTextWidget
│   │       ├── button.dart           # LuaButtonWidget
│   │       ├── column.dart           # LuaColumnWidget
│   │       ├── row.dart              # LuaRowWidget
│   │       └── widget_serializers.g.dart  # Generated serializers
│   └── main.dart
├── rust/
│   ├── Cargo.toml
│   └── src/
│       ├── lib.rs
│       ├── api/
│       │   └── lua.rs                # FFI API functions
│       ├── lua_engine.rs            # Lua execution engine
│       ├── state.rs                  # State management
│       ├── callbacks.rs              # Callback registry
│       └── widgets.rs                # Generated widget structs
├── tool/
│   └── codegen/
│       ├── pubspec.yaml
│       ├── build.yaml
│       └── lib/
│           ├── codegen.dart          # CLI entry point
│           ├── generators/
│           │   ├── rust_generator.dart
│           │   └── dart_serializer_generator.dart
│           ├── models/
│           │   └── widget_info.dart
│           └── parsers/
│               └── annotation_parser.dart
└── plan.md
```

---

## Notes

1. **Parser Implementation**: The analyzer library version 7.x has a different API than 6.x. Need to ensure compatibility.

2. **Rust Version**: The project uses `flutter_rust_bridge` which requires specific Rust toolchain configuration.

3. **Codegen Execution**: The code generator can be run via `flutter pub run lua_plugin_codegen` or as a build_runner builder.

4. **Testing**: Use `cargo check` for Rust and `flutter analyze` for Dart to verify generated code.

5. **Error Handling**: Need to ensure good error messages flow from Lua through Rust to Dart.

---

*Plan updated: 2026-08-12*
