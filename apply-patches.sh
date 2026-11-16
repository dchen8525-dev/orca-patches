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

# List "path<TAB>target blob" for files a patch creates. An interrupted earlier run can leave
# those files in the working tree; keep them only when their bytes match the patch exactly.
new_file_targets() {
  awk '
    function emit() { if (isnew && path != "" && hash != "") print path "\t" hash }
    /^diff --git / { emit(); isnew = 0; path = ""; hash = "" }
    /^new file mode / { isnew = 1 }
    /^\+\+\+ b\// { path = substr($0, 7) }
    /^index 00000000000\.\./ {
      line = $0
      sub(/^index [0-9a-f]+\.\./, "", line)
      split(line, parts, " ")
      hash = parts[1]
    }
    END { emit() }
  ' "$1"
}

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
    excludes=()
    verified=1
    while IFS=$'\t' read -r path expected; do
      [ -n "$path" ] || continue
      # Patch index lines carry abbreviated blob ids; compare the same prefix length.
      actual="$(git hash-object "$path" 2>/dev/null)" || actual=""
      if [ ! -f "$path" ] || [ "${actual:0:${#expected}}" != "$expected" ]; then
        verified=0
        break
      fi
      excludes+=(--exclude="$path")
    done < <(new_file_targets "$patch")
    if [ "$verified" -eq 1 ] && [ ${#excludes[@]} -gt 0 ] &&
       git apply --check "${excludes[@]}" "$patch" 2>/dev/null; then
      git apply "${excludes[@]}" "$patch"
      echo "APPLIED  $name (existing new files verified, skipped)"
    else
      echo "CONFLICT $name" >&2
      FAILED+=("$name")
    fi
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
