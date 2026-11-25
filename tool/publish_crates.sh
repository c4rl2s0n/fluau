#!/usr/bin/env bash
# Publish fluau_macros then fluau to crates.io (requires verified email + cargo login).
#
# Usage (from repo root, preferably on a clean commit):
#   ./tool/publish_crates.sh
#   ./tool/publish_crates.sh --allow-dirty

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXTRA=()
if [[ "${1:-}" == "--allow-dirty" ]]; then
  EXTRA+=(--allow-dirty)
fi

echo "==> Publishing fluau_macros 0.1.0"
(cd "$ROOT/crates/fluau_macros" && cargo publish "${EXTRA[@]}")

echo "==> Waiting for crates.io index…"
sleep 15

echo "==> Publishing fluau 0.1.0"
(cd "$ROOT/crates/fluau" && cargo publish "${EXTRA[@]}")

echo "Done. https://crates.io/crates/fluau_macros  https://crates.io/crates/fluau"
