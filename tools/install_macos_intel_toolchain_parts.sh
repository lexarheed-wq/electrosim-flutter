#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PARTS_DIR="${1:-$PWD}"
ARCHIVE="flutter_macos_3.38.10-stable.zip"
EXPECTED="b7056ba00082b9b814415e7516287bb94633c1108838bfe10f8f665307b99afa"
DEST_DIR="$ROOT/toolchain/archives"
DEST="$DEST_DIR/$ARCHIVE"

shopt -s nullglob
PARTS=("$PARTS_DIR/$ARCHIVE".part-*)
shopt -u nullglob

if [ "${#PARTS[@]}" -eq 0 ]; then
  echo "Aucun morceau de toolchain trouvé dans: $PARTS_DIR" >&2
  exit 66
fi

mkdir -p "$DEST_DIR"
TMP="$DEST.tmp"
rm -f "$TMP"
cat "${PARTS[@]}" > "$TMP"

ACTUAL="$(python3 - "$TMP" <<'PY'
import hashlib, sys
h = hashlib.sha256()
with open(sys.argv[1], 'rb') as f:
    for block in iter(lambda: f.read(1024 * 1024), b''):
        h.update(block)
print(h.hexdigest())
PY
)"

if [ "$ACTUAL" != "$EXPECTED" ]; then
  rm -f "$TMP"
  echo "TOOLCHAIN_SHA256_MISMATCH expected=$EXPECTED actual=$ACTUAL" >&2
  exit 67
fi

mv "$TMP" "$DEST"
printf '%s  %s\n' "$ACTUAL" "$ARCHIVE" > "$ROOT/toolchain/SHA256SUMS.txt"

echo "MACOS_INTEL_TOOLCHAIN_ARCHIVE_PASS"
echo "$DEST"
echo "SHA-256 $ACTUAL"
