fn main() {
    // Terminate hook is only needed for the Luau runtime (C++ exceptions).
    if std::env::var("CARGO_FEATURE_RUNTIME").is_err() {
        return;
    }

    println!("cargo:rerun-if-changed=src/cpp/terminate_hook.cpp");
    cc::Build::new()
        .cpp(true)
        .std("c++17")
        .file("src/cpp/terminate_hook.cpp")
        .compile("fluau_terminate_hook");
}
