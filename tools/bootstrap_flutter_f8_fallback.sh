#!/usr/bin/env bash
set -euo pipefail

# Isolated bootstrap: installs the locked Flutter SDK under .toolchain/ only.
# It never edits ~/.zprofile, ~/.zshrc, ~/.bashrc or a system-wide SDK.
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/ci/TOOLCHAIN_LOCK.json"
BASE="${FLUTTER_STORAGE_BASE_URL:-https://storage.googleapis.com}"
DEST="$ROOT/.toolchain"
mkdir -p "$DEST"

read_lock() {
  python3 - "$LOCK" "$1" <<'PY'
import json,sys
p=json.load(open(sys.argv[1],encoding='utf-8'))
cur=p
for k in sys.argv[2].split('.'):
    cur=cur[k]
print(cur)
PY
}

VERSION="$(read_lock flutter.version)"
CHANNEL="$(read_lock flutter.channel)"
OS="$(uname -s)"
ARCH="$(uname -m)"

if [ "$OS" = "Darwin" ]; then
  MACOS_VERSION="$(sw_vers -productVersion 2>/dev/null || true)"
  echo "Detected macOS: ${MACOS_VERSION:-unknown} ($ARCH)"
  if [ -n "$MACOS_VERSION" ]; then
    MACOS_MAJOR="${MACOS_VERSION%%.*}"
    if [ "$MACOS_MAJOR" -lt 12 ]; then
      echo "Unsupported ElectroSim development host: macOS $MACOS_VERSION is older than Monterey 12" >&2
      exit 67
    fi
    if [ "$MACOS_MAJOR" -eq 12 ]; then
      echo "Monterey compatibility profile: Flutter $VERSION will be validated by the F8 gate."
    fi
  fi
fi
case "$OS/$ARCH" in
  Linux/x86_64) KEY="linux_x64"; DIR="linux" ;;
  Darwin/x86_64) KEY="macos_x64"; DIR="macos" ;;
  Darwin/arm64) KEY="macos_arm64"; DIR="macos" ;;
  *) echo "Unsupported bootstrap platform: $OS/$ARCH" >&2; exit 64 ;;
esac
ARCHIVE="$(read_lock archives.$KEY.filename)"
EXPECTED_SHA="$(read_lock archives.$KEY.sha256)"
URL="$BASE/flutter_infra_release/releases/$CHANNEL/$DIR/$ARCHIVE"
FILE="$DEST/$ARCHIVE"

# Reuse a previously downloaded, hash-verified archive from a sibling F0
# candidate when possible. This avoids another ~2 GB download after a gate fix.
if [ ! -f "$FILE" ]; then
  for CANDIDATE in "$ROOT"/../ElectroSim-Flutter-F*-R*-MONTEREY-CANDIDATE/.toolchain/"$ARCHIVE"; do
    [ -f "$CANDIDATE" ] || continue
    CANDIDATE_SHA="$(python3 - "$CANDIDATE" <<'PY'
import hashlib,sys
h=hashlib.sha256()
with open(sys.argv[1],'rb') as f:
    for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
print(h.hexdigest())
PY
)"
    if [ "$CANDIDATE_SHA" = "$EXPECTED_SHA" ]; then
      echo "Reusing verified Flutter archive from: $CANDIDATE"
      ln "$CANDIDATE" "$FILE" 2>/dev/null || cp "$CANDIDATE" "$FILE"
      break
    fi
  done
fi

if [ ! -f "$FILE" ]; then
  echo "Downloading Flutter $VERSION from: $URL"
  curl --fail --location --retry 3 --output "$FILE.part" "$URL"
  mv "$FILE.part" "$FILE"
fi

ACTUAL_SHA="$(python3 - "$FILE" <<'PY'
import hashlib,sys
h=hashlib.sha256()
with open(sys.argv[1],'rb') as f:
    for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
print(h.hexdigest())
PY
)"
if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
  echo "Flutter archive SHA-256 mismatch" >&2
  echo "expected=$EXPECTED_SHA" >&2
  echo "actual=$ACTUAL_SHA" >&2
  exit 66
fi

echo "Flutter archive integrity: PASS"
rm -rf "$DEST/flutter"
case "$FILE" in
  *.tar.xz) tar -xf "$FILE" -C "$DEST" ;;
  *.zip) unzip -q "$FILE" -d "$DEST" ;;
  *) echo "Unknown SDK archive format" >&2; exit 65 ;;
esac
export PATH="$DEST/flutter/bin:$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true
flutter config --no-analytics >/dev/null 2>&1 || true
flutter --version
dart --version
exec "$ROOT/tools/run_f8_gate.sh"
