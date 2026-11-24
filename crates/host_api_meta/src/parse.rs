//! syn-based parsing of annotated host API sources.

use std::fs;
use std::path::Path;

use syn::{
    parse_file, Attribute, Fields, FnArg, GenericArgument, Item, Meta, Pat, PathArguments,
    ReturnType, TraitItem, Type, TypePath,
};
use thiserror::Error;
use walkdir::WalkDir;

use crate::model::{
    HostApiModel, HostField, HostMethod, HostModule, HostTypeDef, HostUserDataDef, LuauType,
};

#[derive(Debug, Error)]
pub enum ParseError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("parse {path}: {source}")]
    Syn {
        path: String,
        #[source]
        source: syn::Error,
    },
}

/// Parse all `.rs` files under `dir` into a combined host API model.
pub fn parse_directory(dir: impl AsRef<Path>) -> Result<HostApiModel, ParseError> {
    let mut model = HostApiModel::default();
    for entry in WalkDir::new(dir.as_ref()).into_iter().filter_map(|e| e.ok()) {
        let path = entry.path();
        if path.extension().and_then(|s| s.to_str()) != Some("rs") {
            continue;
        }
        let src = fs::read_to_string(path)?;
        let file_model = parse_source(&src).map_err(|e| ParseError::Syn {
            path: path.display().to_string(),
            source: e,
        })?;
        merge(&mut model, file_model);
    }
    model.types.sort_by(|a, b| a.name.cmp(&b.name));
    model.userdata.sort_by(|a, b| a.name.cmp(&b.name));
    model.modules.sort_by(|a, b| a.path.cmp(&b.path));
    Ok(model)
}

/// Parse a single Rust source string.
pub fn parse_source(src: &str) -> Result<HostApiModel, syn::Error> {
    let file = parse_file(src)?;
    let mut model = HostApiModel::default();

    for item in file.items {
        match item {
            Item::Struct(s) => {
                if has_derive(&s.attrs, "HostType") {
                    model.types.push(parse_host_type(&s)?);
                }
                if has_derive(&s.attrs, "HostUserData") {
                    let rust_name = s.ident.to_string();
                    let name =
                        lua_name_from_attrs(&s.attrs).unwrap_or_else(|| rust_name.clone());
                    if !model.userdata.iter().any(|u| u.rust_name == rust_name) {
                        model.userdata.push(HostUserDataDef {
                            name,
                            rust_name,
                            methods: vec![],
                        });
                    }
                }
            }
            Item::Trait(t) => {
                if let Some(path) = host_module_path(&t.attrs) {
                    model.modules.push(parse_host_module(&t, &path)?);
                }
            }
            Item::Impl(im) => {
                if has_path_attr(&im.attrs, "host_userdata") {
                    if let Type::Path(TypePath { path, .. }) = &*im.self_ty {
                        if let Some(ident) = path.get_ident() {
                            let rust_name = ident.to_string();
                            let methods = parse_impl_methods(&im.items)?;
                            if let Some(existing) = model
                                .userdata
                                .iter_mut()
                                .find(|u| u.rust_name == rust_name)
                            {
                                existing.methods = methods;
                            } else {
                                model.userdata.push(HostUserDataDef {
                                    name: rust_name.clone(),
                                    rust_name,
                                    methods,
                                });
                            }
                        }
                    }
                }
            }
            _ => {}
        }
    }

    Ok(model)
}

fn merge(into: &mut HostApiModel, from: HostApiModel) {
    for t in from.types {
        if !into.types.iter().any(|x| x.name == t.name) {
            into.types.push(t);
        }
    }
    for u in from.userdata {
        if let Some(existing) = into
            .userdata
            .iter_mut()
            .find(|x| x.rust_name == u.rust_name)
        {
            if !u.methods.is_empty() {
                existing.methods = u.methods;
            }
            // Prefer explicit lua name if already set.
            if existing.name == existing.rust_name && u.name != u.rust_name {
                existing.name = u.name;
            }
        } else {
            into.userdata.push(u);
        }
    }
    for m in from.modules {
        if !into.modules.iter().any(|x| x.path == m.path) {
            into.modules.push(m);
        }
    }
}

fn parse_host_type(s: &syn::ItemStruct) -> Result<HostTypeDef, syn::Error> {
    let Fields::Named(fields) = &s.fields else {
        return Err(syn::Error::new_spanned(
            &s.ident,
            "HostType requires named fields",
        ));
    };
    let mut out = Vec::new();
    for f in &fields.named {
        let rust_name = f
            .ident
            .as_ref()
            .ok_or_else(|| syn::Error::new_spanned(f, "missing field name"))?
            .to_string();
        let name = serde_rename(&f.attrs).unwrap_or(rust_name);
        out.push(HostField {
            name,
            ty: rust_type_to_luau(&f.ty),
        });
    }
    Ok(HostTypeDef {
        name: s.ident.to_string(),
        fields: out,
    })
}

fn serde_rename(attrs: &[Attribute]) -> Option<String> {
    for attr in attrs {
        if !attr.path().is_ident("serde") {
            continue;
        }
        let mut rename = None;
        let _ = attr.parse_nested_meta(|meta| {
            if meta.path.is_ident("rename") {
                let value = meta.value()?;
                let lit: syn::LitStr = value.parse()?;
                rename = Some(lit.value());
            }
            Ok(())
        });
        if rename.is_some() {
            return rename;
        }
    }
    None
}

fn parse_host_module(t: &syn::ItemTrait, path: &str) -> Result<HostModule, syn::Error> {
    let mut methods = Vec::new();
    for item in &t.items {
        let TraitItem::Fn(m) = item else { continue };
        let lua_name = lua_name_from_attrs(&m.attrs).unwrap_or_else(|| m.sig.ident.to_string());
        let (params, ret) = parse_signature(&m.sig)?;
        methods.push(HostMethod {
            lua_name,
            params,
            ret,
        });
    }
    Ok(HostModule {
        path: path.to_string(),
        methods,
    })
}

fn parse_impl_methods(items: &[syn::ImplItem]) -> Result<Vec<HostMethod>, syn::Error> {
    let mut methods = Vec::new();
    for item in items {
        let syn::ImplItem::Fn(m) = item else { continue };
        // Skip private helpers without #[lua]
        let Some(lua_name) = lua_name_from_attrs(&m.attrs) else {
            continue;
        };
        let (params, ret) = parse_signature(&m.sig)?;
        methods.push(HostMethod {
            lua_name,
            params,
            ret,
        });
    }
    Ok(methods)
}

fn parse_signature(
    sig: &syn::Signature,
) -> Result<(Vec<(String, LuauType)>, LuauType), syn::Error> {
    let mut params = Vec::new();
    for arg in &sig.inputs {
        match arg {
            FnArg::Receiver(_) => {}
            FnArg::Typed(pt) => {
                let name = match &*pt.pat {
                    Pat::Ident(id) => id.ident.to_string(),
                    _ => format!("arg{}", params.len()),
                };
                params.push((name, rust_type_to_luau(&pt.ty)));
            }
        }
    }
    let ret = match &sig.output {
        ReturnType::Default => LuauType::Nil,
        ReturnType::Type(_, ty) => rust_type_to_luau(ty),
    };
    Ok((params, ret))
}

pub fn rust_type_to_luau(ty: &Type) -> LuauType {
    match ty {
        Type::Tuple(t) if t.elems.is_empty() => LuauType::Nil,
        Type::Path(p) => path_to_luau(p),
        Type::Reference(r) => rust_type_to_luau(&r.elem),
        Type::Paren(p) => rust_type_to_luau(&p.elem),
        _ => LuauType::Any,
    }
}

fn path_to_luau(p: &TypePath) -> LuauType {
    let last = match p.path.segments.last() {
        Some(s) => s,
        None => return LuauType::Any,
    };
    let name = last.ident.to_string();
    match name.as_str() {
        "bool" => LuauType::Boolean,
        "String" | "str" => LuauType::String,
        "i8" | "i16" | "i32" | "i64" | "u8" | "u16" | "u32" | "u64" | "usize" | "isize"
        | "f32" | "f64" => LuauType::Number,
        "()" => LuauType::Nil,
        "Option" => match extract_generic(&last.arguments) {
            Some(inner) => LuauType::Optional(Box::new(rust_type_to_luau(&inner))),
            None => LuauType::Any,
        },
        "Result" => match extract_generic(&last.arguments) {
            // Result<T, E> → T in stubs
            Some(inner) => rust_type_to_luau(&inner),
            None => LuauType::Any,
        },
        "Vec" => match extract_generic(&last.arguments) {
            Some(inner) => LuauType::Array(Box::new(rust_type_to_luau(&inner))),
            None => LuauType::Any,
        },
        "HashMap" => {
            // HashMap<String, V>
            if let PathArguments::AngleBracketed(args) = &last.arguments {
                let mut tys = args.args.iter().filter_map(|a| match a {
                    GenericArgument::Type(t) => Some(t.clone()),
                    _ => None,
                });
                let _key = tys.next();
                if let Some(val) = tys.next() {
                    return LuauType::StringMap(Box::new(rust_type_to_luau(&val)));
                }
            }
            LuauType::Any
        }
        "Value" | "JsonValue" => LuauType::Any,
        other => LuauType::Named(other.to_string()),
    }
}

fn extract_generic(args: &PathArguments) -> Option<Type> {
    let PathArguments::AngleBracketed(a) = args else {
        return None;
    };
    a.args.iter().find_map(|arg| match arg {
        GenericArgument::Type(t) => Some(t.clone()),
        _ => None,
    })
}

fn has_derive(attrs: &[Attribute], name: &str) -> bool {
    for attr in attrs {
        if !attr.path().is_ident("derive") {
            continue;
        }
        let mut found = false;
        let _ = attr.parse_nested_meta(|meta| {
            if meta.path.is_ident(name) {
                found = true;
            }
            Ok(())
        });
        if found {
            return true;
        }
    }
    false
}

fn has_path_attr(attrs: &[Attribute], name: &str) -> bool {
    attrs.iter().any(|a| a.path().is_ident(name))
}

fn host_module_path(attrs: &[Attribute]) -> Option<String> {
    for attr in attrs {
        if !attr.path().is_ident("host_module") {
            continue;
        }
        let mut path = None;
        let _ = attr.parse_nested_meta(|meta| {
            if meta.path.is_ident("path") {
                let value = meta.value()?;
                let lit: syn::LitStr = value.parse()?;
                path = Some(lit.value());
            }
            Ok(())
        });
        return path;
    }
    None
}

fn lua_name_from_attrs(attrs: &[Attribute]) -> Option<String> {
    for attr in attrs {
        if !attr.path().is_ident("lua") {
            continue;
        }
        let mut name = None;
        let _ = attr.parse_nested_meta(|meta| {
            if meta.path.is_ident("name") {
                let value = meta.value()?;
                let lit: syn::LitStr = value.parse()?;
                name = Some(lit.value());
            }
            Ok(())
        });
        if name.is_some() {
            return name;
        }
        // Bare #[lua] — fall through
        if matches!(attr.meta, Meta::Path(_)) {
            return None;
        }
    }
    None
}
