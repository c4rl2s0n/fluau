#!/usr/bin/env bash
# Regenerate widget bindings + Luau stubs, capability Luau stubs, host.d.luau.
#
# Usage (from repo root):
#   ./tool/generate.sh
#
# Dart capability parts (*.g.dart): prefer build_runner in the example app:
#   cd example && dart run build_runner build
# This script still runs build_runner so a full refresh stays one command.
#
# Does NOT run flutter_rust_bridge_codegen — only needed when FRB APIs change.
# Does NOT rewrite assets/plugins/_types/plugin.d.luau (hand-maintained).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
EXAMPLE="$ROOT/example"
WIDGETS="$EXAMPLE/lib/widgets"

echo "==> Widget codegen (Dart catalog → serializers, lua_engine.rs, ui.d.luau)"
(
  cd tool/codegen
  dart pub get
  dart run bin/fluau_codegen.dart --generate \
    --input "$WIDGETS" \
    --rust-out "$EXAMPLE/rust/src" \
    --dart-out "$WIDGETS" \
    --luau-out "$EXAMPLE/assets/plugins/_types"
)

echo "==> Capability Dart parts (build_runner → example/lib/*.g.dart)"
(
  cd "$EXAMPLE"
  dart run build_runner build
)

echo "==> Capability Luau stubs (CLI → capabilities.d.luau)"
(
  cd tool/codegen
  dart pub get
  dart run bin/fluau_codegen.dart --generate-capabilities \
    --input "$EXAMPLE/lib" \
    --luau-out "$EXAMPLE/assets/plugins/_types"
)

echo "==> Host stubs (Cargo build.rs → host.d.luau)"
(
  cd "$EXAMPLE/rust"
  cargo build -q
)

echo ""
echo "Generated / refreshed:"
echo "  example/assets/plugins/_types/ui.d.luau"
echo "  example/assets/plugins/_types/host.d.luau"
echo "  example/assets/plugins/_types/capabilities.d.luau"
echo "  example/lib/widgets/widget_serializers.g.dart"
echo "  example/rust/src/lua_engine.rs (+ api/lua.rs)"
echo "  example/lib/*.g.dart (via build_runner)"
echo ""
echo "Hand-maintained (not touched): example/assets/plugins/_types/plugin.d.luau"
echo "Capability-only Dart refresh: cd example && dart run build_runner build"
echo "If you changed flutter_rust_bridge APIs, also run: flutter_rust_bridge_codegen generate"
echo "Bootstrap FRB/Dart adapter: cd example && dart run ../packages/fluau/bin/bootstrap.dart"
echo "Done."
