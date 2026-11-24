//! Regenerate Luau host stubs from annotated host API sources on every build.

use std::env;
use std::fs;
use std::path::PathBuf;

fn main() {
    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap());
    let host_src = manifest_dir.join("src/demo_host");
    println!("cargo:rerun-if-changed={}", host_src.display());

    for name in [
        "types.rs",
        "db_api.rs",
        "http_api.rs",
        "crypto_api.rs",
        "log_api.rs",
    ] {
        println!(
            "cargo:rerun-if-changed={}",
            host_src.join(name).display()
        );
    }

    let stubs = match host_api_meta::generate_luau_stubs(&host_src) {
        Ok(s) => s,
        Err(e) => {
            println!("cargo:warning=host_api stub generation failed: {e}");
            return;
        }
    };

    let out = manifest_dir.join("../assets/plugins/_types/host.d.luau");
    if let Some(parent) = out.parent() {
        let _ = fs::create_dir_all(parent);
    }

    let previous = fs::read_to_string(&out).unwrap_or_default();
    if previous != stubs {
        if let Err(e) = fs::write(&out, &stubs) {
            println!(
                "cargo:warning=failed to write {}: {e}",
                out.display()
            );
        } else {
            println!("cargo:warning=updated {}", out.display());
        }
    }
}
