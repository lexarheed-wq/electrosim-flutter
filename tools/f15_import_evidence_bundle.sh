#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE="${1:?path to evidence bundle zip required}"
[ -f "$BUNDLE" ] || { echo "F15_EVIDENCE_BUNDLE_MISSING $BUNDLE" >&2; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/electrosim-f15-evidence.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
python3 - "$BUNDLE" "$TMP" <<'PY'
from pathlib import Path
import sys,zipfile
z=Path(sys.argv[1]); out=Path(sys.argv[2])
with zipfile.ZipFile(z) as f:
    for info in f.infolist():
        name=Path(info.filename)
        if name.is_absolute() or '..' in name.parts: raise SystemExit('unsafe evidence bundle path')
    f.extractall(out)
PY
DEST="$ROOT/docs/f15/evidence"; mkdir -p "$DEST"
count=0
for target in macos windows linux android ios; do
  src="$(find "$TMP" -type f -name "$target.json" -print -quit)"
  [ -n "$src" ] || continue
  python3 "$ROOT/tools/f15_validate_evidence_file.py" "$target" "$src"
  cp "$src" "$DEST/$target.json"
  count=$((count+1))
done
[ "$count" -gt 0 ] || { echo 'F15_EVIDENCE_BUNDLE_EMPTY' >&2; exit 3; }
echo "F15_EVIDENCE_BUNDLE_IMPORT_PASS $count"
