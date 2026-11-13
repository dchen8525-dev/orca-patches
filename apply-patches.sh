#!/usr/bin/env bash
# Apply all patches in patches/ (sorted by filename) to the orca repo.
# Usage: ./apply-patches.sh /d/work/orca
set -euo pipefail

ORCA_DIR="${1:-}"
if [ -z "$ORCA_DIR" ]; then
  echo "Usage: $0 <path-to-orca-repo>" >&2
  exit 1
fi
if [ ! -f "$ORCA_DIR/package.json" ]; then
  echo "ERROR: $ORCA_DIR does not look like the orca repo root" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ORCA_DIR"

FAILED=()
for patch in "$SCRIPT_DIR"/patches/*.patch; do
  [ -e "$patch" ] || continue
  name="$(basename "$patch")"
  if git apply --check "$patch" 2>/dev/null; then
    git apply "$patch"
    echo "APPLIED  $name"
  elif git apply --check --reverse "$patch" 2>/dev/null; then
    echo "SKIPPED  $name (already applied)"
  else
    echo "CONFLICT $name" >&2
    FAILED+=("$name")
  fi
done

if [ ${#FAILED[@]} -gt 0 ]; then
  echo "" >&2
  echo "FAILED patches (rebase them against latest main):" >&2
  printf '  %s\n' "${FAILED[@]}" >&2
  exit 2
fi
echo ""
echo "All patches applied. Next: see BUILD.md for the full build chain."
