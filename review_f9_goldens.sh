#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DIR="$ROOT/apps/electrosim/test/goldens"
FILES=(
  f9_compact_base.png f9_compact_palette.png f9_compact_properties.png
  f9_medium_base.png f9_medium_palette.png f9_medium_properties.png
  f9_expanded_base.png f9_expanded_palette.png f9_expanded_properties.png
  f9_compact_student_diagnostic.png
)
for f in "${FILES[@]}"; do
  [ -f "$DIR/$f" ] || { echo "Missing golden: $DIR/$f" >&2; exit 41; }
done
if [ "$(uname -s)" = "Darwin" ]; then
  open -a Preview "${FILES[@]/#/$DIR/}"
else
  printf '%s\n' "${FILES[@]/#/$DIR/}"
fi
