#!/usr/bin/env bash
# Regenerate widget bindings + Luau stubs, then refresh host.d.luau via Cargo.
#
# Usage (from repo root):
#   ./tool/generate.sh
#
# Does NOT run flutter_rust_bridge_codegen — only needed when FRB APIs change.
# Does NOT rewrite assets/plugins/_types/plugin.d.luau (hand-maintained).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Widget codegen (Dart catalog → serializers, lua_engine.rs, ui.d.luau)"
(
  cd tool/codegen
  dart pub get
  dart run bin/lua_plugin_codegen.dart --generate \
    --input ../../lib/lua/widgets \
    --rust-out ../../rust/src \
    --dart-out ../../lib/lua/widgets \
    --luau-out ../../assets/plugins/_types
)

echo "==> Host stubs (Cargo build.rs → host.d.luau)"
(
  cd rust
  cargo build -q
)

echo ""
echo "Generated / refreshed:"
echo "  assets/plugins/_types/ui.d.luau"
echo "  assets/plugins/_types/host.d.luau"
echo "  lib/lua/widgets/widget_serializers.g.dart"
echo "  rust/src/lua_engine.rs (+ rust/src/api/lua.rs)"
echo ""
echo "Hand-maintained (not touched): assets/plugins/_types/plugin.d.luau"
echo "If you changed flutter_rust_bridge APIs, also run: flutter_rust_bridge_codegen generate"
echo "Done."
