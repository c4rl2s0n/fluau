//! Proc macros for the modular host API.
//!
//! - `#[derive(HostType)]` — serde↔Lua table conversions
//! - `#[derive(HostUserData)]` — marker (methods via `#[host_userdata]`)
//! - `#[host_module(path = "...")]` on traits — strips `#[lua]` and generates `install_into`
//! - `#[host_userdata]` on inherent impls — generates `mlua::UserData`

use proc_macro::TokenStream;
use quote::{format_ident, quote};
use syn::{
    parse_macro_input, parse_quote, Attribute, FnArg, Ident, ImplItem, ItemImpl, ItemTrait,
    LitStr, Pat, ReturnType, TraitItem, Type,
};

/// Derive Lua table conversions via mlua serde helpers.
#[proc_macro_derive(HostType)]
pub fn derive_host_type(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as syn::DeriveInput);
    let name = &input.ident;
    let (impl_generics, ty_generics, where_clause) = input.generics.split_for_impl();

    let expanded = quote! {
        impl #impl_generics ::mlua::FromLua for #name #ty_generics #where_clause {
            fn from_lua(
                value: ::mlua::Value,
                lua: &::mlua::Lua,
            ) -> ::mlua::Result<Self> {
                use ::mlua::LuaSerdeExt;
                lua.from_value(value)
            }
        }

        impl #impl_generics ::mlua::IntoLua for #name #ty_generics #where_clause {
            fn into_lua(self, lua: &::mlua::Lua) -> ::mlua::Result<::mlua::Value> {
                use ::mlua::LuaSerdeExt;
                lua.to_value(&self)
            }
        }
    };
    expanded.into()
}

/// Marker derive for userdata types (methods come from `#[host_userdata]`).
#[proc_macro_derive(HostUserData)]
pub fn derive_host_userdata(input: TokenStream) -> TokenStream {
    let input = parse_macro_input!(input as syn::DeriveInput);
    let _name = &input.ident;
    // Marker only — UserData impl is emitted by #[host_userdata].
    quote! {}.into()
}

/// Annotate a host module trait. Generates `install_into` default method.
///
/// ```ignore
/// #[host_module(path = "db")]
/// pub trait HostDb {
///     #[lua(name = "get")]
///     fn get(&self, key: String) -> Option<String>;
/// }
/// ```
#[proc_macro_attribute]
pub fn host_module(attr: TokenStream, item: TokenStream) -> TokenStream {
    let args = parse_macro_input!(attr as HostModuleArgs);
    let mut trait_item = parse_macro_input!(item as ItemTrait);
    let path = args.path;
    let permission = args.permission.unwrap_or_else(|| path.clone());
    let summary = args.summary.unwrap_or_default();
    let trait_name = trait_item.ident.clone();
    let perm_const = format_ident!("{}_PERMISSION_ID", trait_name.to_string().to_uppercase());
    let summary_const = format_ident!("{}_SUMMARY", trait_name.to_string().to_uppercase());

    let mut install_bindings = Vec::new();

    for item in &mut trait_item.items {
        let TraitItem::Fn(method) = item else { continue };
        let lua_name = take_lua_name(&mut method.attrs)
            .unwrap_or_else(|| method.sig.ident.to_string());
        let rust_name = &method.sig.ident;
        let binding = generate_trait_method_binding(&lua_name, rust_name, &method.sig);
        install_bindings.push(binding);
    }

    let path_segments: Vec<&str> = path.split('.').collect();
    let install_table_code = if path_segments.len() == 1 {
        let seg = path_segments[0];
        quote! {
            let __mod = lua.create_table()?;
            #(#install_bindings)*
            root.set(#seg, __mod)?;
        }
    } else {
        // Nested path support (rare for phase 1)
        quote! {
            let __mod = lua.create_table()?;
            #(#install_bindings)*
            root.set(#path, __mod)?;
        }
    };

    let install_fn: TraitItem = parse_quote! {
        /// Install this module under `host.<path>`.
        fn install_into(
            root: &::mlua::Table,
            host: Self,
            lua: &::mlua::Lua,
        ) -> ::mlua::Result<()>
        where
            Self: ::std::clone::Clone + ::std::marker::Send + ::std::marker::Sync + 'static,
        {
            #install_table_code
            Ok(())
        }
    };
    trait_item.items.push(install_fn);

    TokenStream::from(quote! {
        #trait_item

        /// Permission id for this host module (manifest / grant key).
        pub const #perm_const: &str = #permission;
        /// Short summary for grant UI.
        pub const #summary_const: &str = #summary;
    })
}

/// Annotate an inherent impl to expose methods as mlua UserData.
#[proc_macro_attribute]
pub fn host_userdata(_attr: TokenStream, item: TokenStream) -> TokenStream {
    let mut impl_item = parse_macro_input!(item as ItemImpl);
    let self_ty = &impl_item.self_ty;

    let mut method_regs = Vec::new();
    for item in &mut impl_item.items {
        let ImplItem::Fn(method) = item else { continue };
        let Some(lua_name) = take_lua_name(&mut method.attrs) else {
            continue;
        };
        let rust_name = &method.sig.ident;
        method_regs.push(generate_userdata_method(&lua_name, rust_name, &method.sig));
    }

    let userdata_impl = quote! {
        impl ::mlua::UserData for #self_ty {
            fn add_methods<M: ::mlua::UserDataMethods<Self>>(methods: &mut M) {
                #(#method_regs)*
            }
        }
    };

    TokenStream::from(quote! {
        #impl_item
        #userdata_impl
    })
}

struct HostModuleArgs {
    path: String,
    permission: Option<String>,
    summary: Option<String>,
}

impl syn::parse::Parse for HostModuleArgs {
    fn parse(input: syn::parse::ParseStream) -> syn::Result<Self> {
        let mut path = None;
        let mut permission = None;
        let mut summary = None;
        while !input.is_empty() {
            let ident: Ident = input.parse()?;
            input.parse::<syn::Token![=]>()?;
            if ident == "path" {
                let lit: LitStr = input.parse()?;
                path = Some(lit.value());
            } else if ident == "permission" {
                let lit: LitStr = input.parse()?;
                permission = Some(lit.value());
            } else if ident == "summary" {
                let lit: LitStr = input.parse()?;
                summary = Some(lit.value());
            } else {
                return Err(syn::Error::new(ident.span(), "unknown host_module arg"));
            }
            if input.peek(syn::Token![,]) {
                input.parse::<syn::Token![,]>()?;
            }
        }
        Ok(HostModuleArgs {
            path: path.ok_or_else(|| input.error("host_module requires path = \"...\""))?,
            permission,
            summary,
        })
    }
}

fn take_lua_name(attrs: &mut Vec<Attribute>) -> Option<String> {
    let mut name = None;
    attrs.retain(|attr| {
        if !attr.path().is_ident("lua") {
            return true;
        }
        let mut n = None;
        let _ = attr.parse_nested_meta(|meta| {
            if meta.path.is_ident("name") {
                let value = meta.value()?;
                let lit: LitStr = value.parse()?;
                n = Some(lit.value());
            }
            Ok(())
        });
        if n.is_some() {
            name = n;
        }
        false // strip #[lua]
    });
    name
}

fn generate_trait_method_binding(
    lua_name: &str,
    rust_name: &Ident,
    sig: &syn::Signature,
) -> proc_macro2::TokenStream {
    let args = non_self_args(sig);
    let ret_wrap = wrap_return(&sig.output, quote! { __ret });

    if args.is_empty() {
        quote! {
            {
                let __host = host.clone();
                __mod.set(#lua_name, lua.create_function(move |lua, ()| {
                    let __ret = __host.#rust_name();
                    #ret_wrap
                })?)?;
            }
        }
    } else if args.len() == 1 {
        let (pat, ty) = &args[0];
        let _ = pat;
        quote! {
            {
                let __host = host.clone();
                __mod.set(#lua_name, lua.create_function(move |lua, __arg: #ty| {
                    let __ret = __host.#rust_name(__arg);
                    #ret_wrap
                })?)?;
            }
        }
    } else {
        let tys: Vec<&Type> = args.iter().map(|(_, t)| t).collect();
        let idents: Vec<Ident> = (0..args.len())
            .map(|i| format_ident!("__a{i}"))
            .collect();
        let tuple_pat = quote! { (#(#idents),*) };
        let tuple_ty = quote! { (#(#tys),*) };
        quote! {
            {
                let __host = host.clone();
                __mod.set(#lua_name, lua.create_function(move |lua, #tuple_pat: #tuple_ty| {
                    let __ret = __host.#rust_name(#(#idents),*);
                    #ret_wrap
                })?)?;
            }
        }
    }
}

fn generate_userdata_method(
    lua_name: &str,
    rust_name: &Ident,
    sig: &syn::Signature,
) -> proc_macro2::TokenStream {
    let args = non_self_args(sig);
    let ret_wrap = wrap_return(&sig.output, quote! { __ret });

    if args.is_empty() {
        quote! {
            methods.add_method(#lua_name, |lua, this, ()| {
                let __ret = this.#rust_name();
                #ret_wrap
            });
        }
    } else if args.len() == 1 {
        let ty = &args[0].1;
        quote! {
            methods.add_method(#lua_name, |lua, this, __arg: #ty| {
                let __ret = this.#rust_name(__arg);
                #ret_wrap
            });
        }
    } else {
        let tys: Vec<&Type> = args.iter().map(|(_, t)| t).collect();
        let idents: Vec<Ident> = (0..args.len())
            .map(|i| format_ident!("__a{i}"))
            .collect();
        let tuple_pat = quote! { (#(#idents),*) };
        let tuple_ty = quote! { (#(#tys),*) };
        quote! {
            methods.add_method(#lua_name, |lua, this, #tuple_pat: #tuple_ty| {
                let __ret = this.#rust_name(#(#idents),*);
                #ret_wrap
            });
        }
    }
}

fn non_self_args(sig: &syn::Signature) -> Vec<(Ident, Type)> {
    let mut out = Vec::new();
    for arg in &sig.inputs {
        match arg {
            FnArg::Receiver(_) => {}
            FnArg::Typed(pt) => {
                let ident = match &*pt.pat {
                    Pat::Ident(id) => id.ident.clone(),
                    _ => format_ident!("arg{}", out.len()),
                };
                out.push((ident, (*pt.ty).clone()));
            }
        }
    }
    out
}

fn wrap_return(output: &ReturnType, ret_expr: proc_macro2::TokenStream) -> proc_macro2::TokenStream {
    match output {
        ReturnType::Default => quote! {
            let _ = #ret_expr;
            Ok(())
        },
        ReturnType::Type(_, ty) => {
            if is_result_unit(ty) {
                quote! {
                    match #ret_expr {
                        ::std::result::Result::Ok(()) => Ok(()),
                        ::std::result::Result::Err(e) => {
                            ::std::result::Result::Err(::mlua::Error::runtime(e))
                        }
                    }
                }
            } else if is_result_type(ty) {
                quote! {
                    match #ret_expr {
                        ::std::result::Result::Ok(v) => ::mlua::IntoLua::into_lua(v, lua),
                        ::std::result::Result::Err(e) => {
                            ::std::result::Result::Err(::mlua::Error::runtime(e))
                        }
                    }
                }
            } else if is_unit_type(ty) {
                quote! {
                    let _ = #ret_expr;
                    Ok(())
                }
            } else {
                quote! {
                    let __v = #ret_expr;
                    ::mlua::IntoLua::into_lua(__v, lua)
                }
            }
        }
    }
}

fn is_result_type(ty: &Type) -> bool {
    match ty {
        Type::Path(p) => p
            .path
            .segments
            .last()
            .map(|s| s.ident == "Result")
            .unwrap_or(false),
        _ => false,
    }
}

fn is_result_unit(ty: &Type) -> bool {
    let Type::Path(p) = ty else {
        return false;
    };
    let Some(seg) = p.path.segments.last() else {
        return false;
    };
    if seg.ident != "Result" {
        return false;
    }
    let syn::PathArguments::AngleBracketed(args) = &seg.arguments else {
        return false;
    };
    let mut tys = args.args.iter().filter_map(|a| match a {
        syn::GenericArgument::Type(t) => Some(t),
        _ => None,
    });
    matches!(tys.next(), Some(t) if is_unit_type(t))
}

fn is_unit_type(ty: &Type) -> bool {
    matches!(ty, Type::Tuple(t) if t.elems.is_empty())
}
