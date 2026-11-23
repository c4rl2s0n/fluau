//! Parse `#[host_module]` traits, `HostType` / `HostUserData` types, and emit Luau stubs.

mod emit;
mod model;
mod parse;

pub use emit::emit_luau;
pub use model::{
    HostApiModel, HostField, HostMethod, HostModule, HostTypeDef, HostUserDataDef, LuauType,
};
pub use parse::{parse_directory, parse_source, ParseError};

/// Convenience: parse a host source tree and return Luau stub file contents.
pub fn generate_luau_stubs(host_src_dir: impl AsRef<std::path::Path>) -> Result<String, ParseError> {
    let mut model = parse_directory(host_src_dir)?;
    rewrite_userdata_names(&mut model);
    Ok(emit_luau(&model))
}

fn rewrite_userdata_names(model: &mut HostApiModel) {
    let renames: Vec<(String, String)> = model
        .userdata
        .iter()
        .filter(|u| u.name != u.rust_name)
        .map(|u| (u.rust_name.clone(), u.name.clone()))
        .collect();
    if renames.is_empty() {
        return;
    }
    for module in &mut model.modules {
        for method in &mut module.methods {
            for (_, ty) in &mut method.params {
                rename_luau_type(ty, &renames);
            }
            rename_luau_type(&mut method.ret, &renames);
        }
    }
    for ud in &mut model.userdata {
        for method in &mut ud.methods {
            for (_, ty) in &mut method.params {
                rename_luau_type(ty, &renames);
            }
            rename_luau_type(&mut method.ret, &renames);
        }
    }
}

fn rename_luau_type(ty: &mut LuauType, renames: &[(String, String)]) {
    match ty {
        LuauType::Named(n) => {
            if let Some((_, to)) = renames.iter().find(|(from, _)| from == n) {
                *n = to.clone();
            }
        }
        LuauType::Optional(inner) | LuauType::StringMap(inner) | LuauType::Array(inner) => {
            rename_luau_type(inner, renames);
        }
        LuauType::Table(fields) => {
            for (_, t) in fields {
                rename_luau_type(t, renames);
            }
        }
        _ => {}
    }
}
