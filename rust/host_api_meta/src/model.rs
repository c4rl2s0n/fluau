//! Intermediate representation of the host API surface.

#[derive(Debug, Clone, Default)]
pub struct HostApiModel {
    pub types: Vec<HostTypeDef>,
    pub userdata: Vec<HostUserDataDef>,
    pub modules: Vec<HostModule>,
}

#[derive(Debug, Clone)]
pub struct HostTypeDef {
    pub name: String,
    pub fields: Vec<HostField>,
}

#[derive(Debug, Clone)]
pub struct HostField {
    pub name: String,
    pub ty: LuauType,
}

#[derive(Debug, Clone)]
pub struct HostUserDataDef {
    /// Lua / stub class name.
    pub name: String,
    /// Rust struct ident (for matching `impl`).
    pub rust_name: String,
    pub methods: Vec<HostMethod>,
}

#[derive(Debug, Clone)]
pub struct HostModule {
    /// Nested path under `host`, e.g. `"db"` or `"http"`.
    pub path: String,
    pub methods: Vec<HostMethod>,
}

#[derive(Debug, Clone)]
pub struct HostMethod {
    /// Lua-visible name.
    pub lua_name: String,
    pub params: Vec<(String, LuauType)>,
    pub ret: LuauType,
}

/// Simplified Luau type used for stub emission.
#[derive(Debug, Clone)]
pub enum LuauType {
    Nil,
    Any,
    Boolean,
    Number,
    String,
    /// Named type (HostType or UserData class).
    Named(String),
    Optional(Box<LuauType>),
    /// `{ [string]: V }`
    StringMap(Box<LuauType>),
    /// `{ T }` array
    Array(Box<LuauType>),
    /// Inline table type for anonymous structs (rare).
    Table(Vec<(String, LuauType)>),
}

impl LuauType {
    pub fn to_luau(&self) -> String {
        match self {
            LuauType::Nil => "nil".into(),
            LuauType::Any => "any".into(),
            LuauType::Boolean => "boolean".into(),
            LuauType::Number => "number".into(),
            LuauType::String => "string".into(),
            LuauType::Named(n) => n.clone(),
            LuauType::Optional(inner) => format!("{}?", inner.to_luau()),
            LuauType::StringMap(v) => format!("{{ [string]: {} }}", v.to_luau()),
            LuauType::Array(v) => format!("{{{}}}", v.to_luau()),
            LuauType::Table(fields) => {
                let body = fields
                    .iter()
                    .map(|(n, t)| format!("{n}: {}", t.to_luau()))
                    .collect::<Vec<_>>()
                    .join(", ");
                format!("{{ {body} }}")
            }
        }
    }
}
