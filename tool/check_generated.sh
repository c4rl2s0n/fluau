#!/usr/bin/env bash
# Fail if committed generated artifacts are stale relative to sources.
#
# Usage (from repo root):
#   ./tool/check_generated.sh
#
# Regenerates via ./tool/generate.sh, then requires a clean git diff on the
# generated paths. Does not require plugin.d.luau (hand-maintained).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: check_generated.sh requires a git working tree" >&2
  exit 1
fi

GENERATED_PATHS=(
  assets/plugins/_types/ui.d.luau
  assets/plugins/_types/host.d.luau
  lib/lua/widgets/widget_serializers.g.dart
  rust/src/lua_engine.rs
  rust/src/api/lua.rs
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
  # Also catch untracked expected files
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
