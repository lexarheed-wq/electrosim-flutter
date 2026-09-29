#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
DIR="$ROOT/packages/electrosim_canvas/test/goldens"
FILES=("$DIR/canvas_compact.png" "$DIR/canvas_medium.png" "$DIR/canvas_expanded.png")
for f in "${FILES[@]}"; do
  if [ ! -f "$f" ]; then
    echo "Missing golden: $f" >&2
    echo "Run ./validate.sh first so the initial baselines are generated." >&2
    exit 2
  fi
done
printf 'F8 goldens to review:\n'
printf '  %s\n' "${FILES[@]}"
if [ "$(uname -s)" = "Darwin" ] && command -v open >/dev/null 2>&1; then
  open "${FILES[@]}"
  echo "Opened the three reference images in macOS."
else
  echo "Open the three PNG files with your image viewer."
fi
echo "After visual approval: python3 tools/approve_f8_goldens.py --approve"
