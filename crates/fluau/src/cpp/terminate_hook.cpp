// Fluau terminate hook: print Luau/C++ exception::what() before abort.
// Linked only when the `runtime` feature builds this translation unit.

#include <cstdlib>
#include <exception>
#include <iostream>

extern "C" {
// Optional context set by Rust (UTF-8, may be null).
const char* fluau_current_plugin_op(void);

static void fluau_terminate_handler() {
    const char* ctx = fluau_current_plugin_op();
    if (ctx && ctx[0] != '\0') {
        std::cerr << "fluau: terminate while " << ctx << std::endl;
    }

    if (std::exception_ptr ep = std::current_exception()) {
        try {
            std::rethrow_exception(ep);
        } catch (const std::exception& e) {
            std::cerr << "fluau: uncaught exception: " << e.what() << std::endl;
        } catch (...) {
            std::cerr << "fluau: uncaught non-std exception" << std::endl;
        }
    } else {
        std::cerr << "fluau: terminate called with no active exception" << std::endl;
    }

    std::abort();
}

void fluau_install_terminate_hook(void) {
    static bool installed = false;
    if (installed) {
        return;
    }
    installed = true;
    std::set_terminate(fluau_terminate_handler);
}
}
