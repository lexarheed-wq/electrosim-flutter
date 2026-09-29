#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LOCK="$ROOT/ci/TOOLCHAIN_LOCK.json"
DEST="$ROOT/.toolchain"
mkdir -p "$DEST"
read_lock(){ python3 - "$LOCK" "$1" <<'PY'
import json,sys
cur=json.load(open(sys.argv[1],encoding='utf-8'))
for key in sys.argv[2].split('.'): cur=cur[key]
print(cur)
PY
}
sha256(){ python3 - "$1" <<'PY'
import hashlib,sys
h=hashlib.sha256()
with open(sys.argv[1],'rb') as f:
    for b in iter(lambda:f.read(1024*1024),b''): h.update(b)
print(h.hexdigest())
PY
}
OS="$(uname -s)"; ARCH="$(uname -m)"
case "$OS/$ARCH" in
  Linux/x86_64) KEY=linux_x64; PLATFORM=linux-x64 ;;
  Darwin/x86_64) KEY=macos_x64; PLATFORM=macos-x64 ;;
  Darwin/arm64) KEY=macos_arm64; PLATFORM=macos-arm64 ;;
  *) echo "Unsupported platform: $OS/$ARCH" >&2; exit 64 ;;
esac
OFFICIAL_ARCHIVE="$(read_lock archives.$KEY.filename)"
OFFICIAL_SHA="$(read_lock archives.$KEY.sha256)"
VERSION="$(read_lock flutter.version)"
DART_VERSION="$(read_lock flutter.dartVersion)"
META="$ROOT/toolchain/LOCAL_TOOLCHAIN.json"
FOUND=""; EXPECTED=""; KIND=""

# Prefer a generated local bundle when its metadata and SHA are valid for this host.
if [ -f "$META" ]; then
  readarray -t local_info < <(python3 - "$META" <<'PY'
import json,sys
x=json.load(open(sys.argv[1],encoding='utf-8'))
for k in ('filename','sha256','platform','flutterVersion','dartVersion'): print(x.get(k,''))
PY
)
  lf="${local_info[0]:-}"; ls="${local_info[1]:-}"; lp="${local_info[2]:-}"; lv="${local_info[3]:-}"; ld="${local_info[4]:-}"
  candidate="$ROOT/toolchain/archives/$lf"
  if [ "$lp" = "$PLATFORM" ] && [ "$lv" = "$VERSION" ] && [ "$ld" = "$DART_VERSION" ] && [ -f "$candidate" ] && [ "$(sha256 "$candidate")" = "$ls" ]; then
    FOUND="$candidate"; EXPECTED="$ls"; KIND="local-bundle"
  fi
fi

# Otherwise accept the official locked archive.
if [ -z "$FOUND" ]; then
  CANDIDATES=()
  [ -n "${ELECTROSIM_FLUTTER_ARCHIVE:-}" ] && CANDIDATES+=("$ELECTROSIM_FLUTTER_ARCHIVE")
  CANDIDATES+=("$ROOT/toolchain/archives/$OFFICIAL_ARCHIVE" "$ROOT/$OFFICIAL_ARCHIVE" "$ROOT/.toolchain/$OFFICIAL_ARCHIVE")
  for f in "${CANDIDATES[@]}"; do
    [ -f "$f" ] || continue
    if [ "$(sha256 "$f")" = "$OFFICIAL_SHA" ]; then FOUND="$f"; EXPECTED="$OFFICIAL_SHA"; KIND="official-archive"; break; fi
  done
fi

if [ -z "$FOUND" ]; then
  cat >&2 <<MSG
OFFLINE_TOOLCHAIN_MISSING
Flutter $VERSION / Dart $DART_VERSION was not found as a verified local bundle or official archive.
Run: ./tools/prepare_offline_toolchain_bundle.sh
No network download was attempted.
MSG
  exit 68
fi

echo "Using verified $KIND: $FOUND"
rm -rf "$DEST/flutter"
case "$FOUND" in
  *.zip) unzip -q "$FOUND" -d "$DEST" ;;
  *.tar.xz) tar -xf "$FOUND" -C "$DEST" ;;
  *) echo "Unsupported Flutter archive format: $FOUND" >&2; exit 65 ;;
esac
FLUTTER="$DEST/flutter/bin/flutter"
DART="$DEST/flutter/bin/cache/dart-sdk/bin/dart"
[ -x "$FLUTTER" ] || { echo "Flutter executable missing after extraction" >&2; exit 69; }
[ -x "$DART" ] || { echo "Dart executable missing after extraction" >&2; exit 69; }
export PATH="$DEST/flutter/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
"$FLUTTER" config --no-analytics >/dev/null 2>&1 || true
ACTUAL_VERSION="$("$FLUTTER" --version 2>&1 | awk 'NR==1 && $1=="Flutter" {print $2}')"
ACTUAL_DART="$("$DART" --version 2>&1 | sed -E 's/^Dart SDK version: ([0-9.]+).*/\1/' | head -1)"
[ "$ACTUAL_VERSION" = "$VERSION" ] || { echo "Flutter version mismatch: expected $VERSION actual $ACTUAL_VERSION" >&2; exit 70; }
[ "$ACTUAL_DART" = "$DART_VERSION" ] || { echo "Dart version mismatch: expected $DART_VERSION actual $ACTUAL_DART" >&2; exit 70; }
echo "LOCAL_FLUTTER_TOOLCHAIN_PASS Flutter $ACTUAL_VERSION / Dart $ACTUAL_DART"
"$FLUTTER" --version
"$DART" --version
