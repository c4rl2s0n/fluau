> **Historical / superseded.** This document describes an earlier UserData-based widget API. The runtime builds UI via JSON constructors and codegen. Prefer [Architecture](../ARCHITECTURE.md) and [Codegen overview](../../CODEGEN_OVERVIEW.md).

# Lua Flutter Plugin - UserData API Implementation

This document describes the UserData-based API implementation for creating Flutter widgets from Lua scripts.

## Overview

The implementation uses **mlua's UserData feature** to provide type-safe Lua ↔ Rust interop. This approach:

1. **Defines Rust structs** (`TextWidget`, `TextStyle`) with `UserData` implementations
2. **Exposes them to Lua** as native types via `ui.Text` constructor
3. **Provides field access** through getter/setter methods
4. **Converts to JSON** for Flutter consumption

## UserData Types

### `TextWidget`

Represents a Flutter Text widget with the following properties:

- `text` (String, required): The text content to display
- `style` (TextStyle, optional): Style properties for the text

**Lua Usage:**
```lua
local widget = ui.Text {
    text = "Hello World",
    style = { fontSize = 24, color = "#FF0000FF" }
}
return widget
```

### `TextStyle`

Represents text styling properties:

- `fontSize` (number, optional): Font size in logical pixels
- `color` (string, optional): Color as hex string (e.g., "#FFAABBCC")
- `fontWeight` (string, optional): Font weight ("normal", "bold", etc.)
- `fontStyle` (string, optional): Font style ("normal", "italic")

## Rust Implementation

### UserData Trait Implementation

```rust
impl UserData for TextWidget {
    fn add_fields<F: UserDataFields<Self>>(fields: &mut F) {
        // Text property
        fields.add_field_method_get("text", |_, this| Ok(this.text.clone()));
        fields.add_field_method_set("text", |_, this, value: String| {
            this.text = value;
            Ok(())
        });
        
        // Style property (returns/accepts Lua tables)
        fields.add_field_method_get("style", |lua, this| {
            let table = lua.create_table()?;
            // Populate table from this.style...
            Ok(Value::Table(table))
        });
        
        fields.add_field_method_set("style", |_, this, value: Value| {
            // Parse Lua table into TextStyle...
            Ok(())
        });
    }
}
```

### Field Handling Strategy

For nested types like `TextStyle`, we use a **hybrid approach**:

1. **Rust side**: `TextStyle` is a plain struct (not UserData)
2. **Lua side**: Exposed as a Lua table for simplicity
3. **Conversion**: Field getter returns Lua table, setter accepts Lua table

This avoids the complexity of nested UserData types while maintaining type safety at the widget level.

### Widget Constructor

The `ui.Text` constructor is registered in Lua:

```rust
ui.set("Text", lua.create_function(|lua, args: Table| {
    let text: String = args.get("text")?;
    let mut widget = TextWidget { text, style: None };
    
    // Parse style table if present
    if let Ok(style_table) = args.get::<Table>("style") {
        widget.style = Some(parse_style_table(style_table)?);
    }
    
    Ok(Value::UserData(lua.create_userdata(widget)?))
})?);
```

## JSON Serialization

Widgets are converted to JSON for Flutter:

```rust
fn text_widget_to_json(widget: &TextWidget) -> JsonValue {
    let mut map = JsonMap::new();
    map.insert("type", "Text");
    map.insert("text", widget.text.clone());
    if let Some(style) = &widget.style {
        // Add style properties...
    }
    JsonValue::Object(map)
}
```

## Extending the API

To add new widget types:

1. **Define the Rust struct**:
   ```rust
   #[derive(Debug, Clone, Serialize, Deserialize)]
   pub struct ButtonWidget {
       pub text: String,
       pub on_pressed: Option<String>, // Callback name
   }
   ```

2. **Implement UserData**:
   ```rust
   impl UserData for ButtonWidget {
       fn add_fields<F: UserDataFields<Self>>(fields: &mut F) {
           fields.add_field_method_get("text", |_, this| Ok(this.text.clone()));
           fields.add_field_method_set("text", |_, this, value| { this.text = value; Ok(()) });
           // ... other fields
       }
   }
   ```

3. **Register the constructor**:
   ```rust
   ui.set("Button", lua.create_function(|lua, args: Table| {
       // Parse args and create ButtonWidget
       Ok(Value::UserData(lua.create_userdata(widget)?))
   })?);
   ```

4. **Add JSON serialization**:
   ```rust
   fn button_widget_to_json(widget: &ButtonWidget) -> JsonValue {
       // Convert to JSON
   }
   ```

5. **Update the main function** to handle the new widget type

## Sandboxing

The implementation uses **Luau's sandboxing** feature:

```rust
let lua = Lua::new();
lua.sandbox(true); // Restrict dangerous operations
```

This prevents Lua scripts from:
- Accessing the filesystem
- Executing shell commands
- Loading external libraries
- Accessing network resources

## Error Handling

Errors are propagated as strings:

```rust
match lua.load(&script).eval::<Value>() {
    Ok(Value::UserData(userdata)) => {
        match userdata.borrow::<TextWidget>() {
            Ok(widget) => Ok(serialize(widget)),
            Err(_) => Err("Invalid widget type".to_string()),
        }
    }
    Err(e) => Err(e.to_string()),
}
```

## Benefits of UserData Approach

1. **Type Safety**: Rust types are exposed directly to Lua
2. **Better Error Messages**: Lua gets type errors for wrong field types
3. **Extensibility**: Easy to add new widget types
4. **Documentation**: Fields are self-documenting in Lua
5. **Performance**: Direct access to Rust types without serialization overhead

## Limitations

1. **Nested UserData**: Complex nested UserData types can be tricky to implement
2. **Lua Version**: Requires mlua with UserData support (mlua 0.9+)
3. **FFI Overhead**: Still has serialization overhead for Flutter communication

## Future Improvements

1. **Callback Support**: Add support for Lua callbacks (e.g., `onPressed`)
2. **State Management**: Add `ui.getState`/`ui.updateState` functions
3. **More Widgets**: Add Column, Row, Button, etc.
4. **Type Checking**: Add runtime type checking for UserData
5. **Documentation**: Generate Lua API documentation from Rust doc comments
