#!/usr/bin/env bash
# Regenerate widget + capability bindings, Luau stubs, host.d.luau, READMEs.
#
# Usage (from repo root):
#   ./tool/generate.sh
#
# Does NOT run flutter_rust_bridge_codegen — only needed when FRB APIs change.
# Does NOT rewrite assets/plugins/_types/plugin.d.luau (hand-maintained).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
EXAMPLE="$ROOT/example"

CODEGEN="$ROOT/packages/fluau_codegen"

echo "==> fluau_codegen (widgets + capabilities from example/fluau.yaml)"
(
  cd "$CODEGEN"
  dart pub get
  (cd "$EXAMPLE" && dart run "$CODEGEN/bin/fluau_codegen.dart")
)

echo "==> Host stubs (Cargo build.rs → host.d.luau)"
(
  cd "$EXAMPLE/rust"
  cargo build -q
)

echo "==> READMEs (templates + doc includes)"
dart run tool/render_readmes.dart

echo ""
echo "Generated / refreshed:"
echo "  example/assets/plugins/_types/ui.d.luau"
echo "  example/assets/plugins/_types/host.d.luau"
echo "  example/assets/plugins/_types/capabilities.d.luau"
echo "  example/lib/fluau/widget_serializers.g.dart"
echo "  example/rust/src/lua_engine.rs (+ api/lua.rs)"
echo "  example/lib/*.g.dart"
echo "  README.md"
echo "  packages/fluau/README.md"
echo ""
echo "Hand-maintained (not touched): example/assets/plugins/_types/plugin.d.luau"
echo "README-only refresh: dart run tool/render_readmes.dart"
echo "If you changed flutter_rust_bridge APIs, also run: flutter_rust_bridge_codegen generate"
echo "Bootstrap FRB/Dart adapter: cd example && dart run ../packages/fluau/bin/bootstrap.dart"
echo "Done."
