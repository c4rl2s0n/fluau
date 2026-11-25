#!/usr/bin/env bash
# Fail if committed generated artifacts are stale relative to sources.
#
# Usage (from repo root):
#   ./tool/check_generated.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: check_generated.sh requires a git working tree" >&2
  exit 1
fi

GENERATED_PATHS=(
  example/assets/plugins/_types/ui.d.luau
  example/assets/plugins/_types/host.d.luau
  example/assets/plugins/_types/capabilities.d.luau
  example/lib/widgets/widget_serializers.g.dart
  example/rust/src/lua_engine.rs
  example/rust/src/api/lua.rs
  example/lib/vpn_provider.g.dart
  README.md
  packages/fluau/README.md
)

echo "==> Regenerating…"
./tool/generate.sh

echo "==> Checking for dirty generated files…"
dirty=0
for path in "${GENERATED_PATHS[@]}"; do
  if ! git diff --quiet -- "$path"; then
    echo "stale: $path"
    dirty=1
  fi
  if [[ ! -f "$path" ]]; then
    echo "missing: $path"
    dirty=1
  fi
done

if [[ "$dirty" -ne 0 ]]; then
  echo ""
  echo "Generated files are out of date (or were not committed)."
  echo "Review the diff, commit the updates, or fix sources and re-run."
  git --no-pager diff --stat -- "${GENERATED_PATHS[@]}" || true
  exit 1
fi

echo "OK: generated artifacts match sources."
