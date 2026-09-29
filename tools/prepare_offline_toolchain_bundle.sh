#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCK="$ROOT/ci/TOOLCHAIN_LOCK.json"
ARCHIVES_DIR="$ROOT/toolchain/archives"
mkdir -p "$ARCHIVES_DIR"

read_lock(){ python3 - "$LOCK" "$1" <<'PY'
import json,sys
cur=json.load(open(sys.argv[1],encoding='utf-8'))
for key in sys.argv[2].split('.'): cur=cur[key]
print(cur)
PY
}
sha256(){
  shasum -a 256 "$1" 2>/dev/null | awk '{print $1}' || python3 - "$1" <<'PY'
import hashlib,sys
h=hashlib.sha256()
with open(sys.argv[1],'rb') as f:
    for b in iter(lambda:f.read(1024*1024),b''): h.update(b)
print(h.hexdigest())
PY
}

OS="$(uname -s)"; ARCH="$(uname -m)"
case "$OS/$ARCH" in
  Darwin/x86_64) KEY=macos_x64; PLATFORM=macos-x64 ;;
  Darwin/arm64) KEY=macos_arm64; PLATFORM=macos-arm64 ;;
  Linux/x86_64) KEY=linux_x64; PLATFORM=linux-x64 ;;
  *) echo "Unsupported platform: $OS/$ARCH" >&2; exit 64 ;;
esac
OFFICIAL_ARCHIVE="$(read_lock archives.$KEY.filename)"
OFFICIAL_SHA="$(read_lock archives.$KEY.sha256)"
FLUTTER_VERSION="$(read_lock flutter.version)"
DART_VERSION="$(read_lock flutter.dartVersion)"
LOCAL_BUNDLE="flutter-local-${PLATFORM}-${FLUTTER_VERSION}.tar.xz"
LOCAL_TARGET="$ARCHIVES_DIR/$LOCAL_BUNDLE"
META="$ROOT/toolchain/LOCAL_TOOLCHAIN.json"

# 1. Prefer an already verified official archive if one exists.
ARCHIVE_CANDIDATES=()
[ -n "${ELECTROSIM_FLUTTER_ARCHIVE:-}" ] && ARCHIVE_CANDIDATES+=("$ELECTROSIM_FLUTTER_ARCHIVE")
ARCHIVE_CANDIDATES+=("$ROOT/.toolchain/$OFFICIAL_ARCHIVE" "$ARCHIVES_DIR/$OFFICIAL_ARCHIVE")
SEARCH_ROOT="${ELECTROSIM_TOOLCHAIN_SEARCH_ROOT:-$HOME/Downloads}"
if [ -d "$SEARCH_ROOT" ]; then
  while IFS= read -r f; do ARCHIVE_CANDIDATES+=("$f"); done < <(find "$SEARCH_ROOT" -type f -name "$OFFICIAL_ARCHIVE" -print 2>/dev/null | head -50)
fi
for f in "${ARCHIVE_CANDIDATES[@]}"; do
  [ -f "$f" ] || continue
  [ "$(sha256 "$f")" = "$OFFICIAL_SHA" ] || continue
  cp -f "$f" "$ARCHIVES_DIR/$OFFICIAL_ARCHIVE"
  printf '%s  %s\n' "$OFFICIAL_SHA" "$OFFICIAL_ARCHIVE" > "$ROOT/toolchain/SHA256SUMS.txt"
  echo "OFFLINE_TOOLCHAIN_BUNDLE_PASS official-archive"
  echo "$ARCHIVES_DIR/$OFFICIAL_ARCHIVE"
  exit 0
done

# 2. Otherwise locate a previously extracted Flutter SDK and create a reusable local bundle.
SDK_CANDIDATES=()
[ -n "${ELECTROSIM_FLUTTER_SDK:-}" ] && SDK_CANDIDATES+=("${ELECTROSIM_FLUTTER_SDK%/}")
[ -d "$ROOT/.toolchain/flutter" ] && SDK_CANDIDATES+=("$ROOT/.toolchain/flutter")
if [ -d "$SEARCH_ROOT" ]; then
  while IFS= read -r exe; do SDK_CANDIDATES+=("$(cd "$(dirname "$exe")/.." && pwd)"); done < <(find "$SEARCH_ROOT" -type f -path '*/.toolchain/flutter/bin/flutter' -print 2>/dev/null | head -100)
fi

verify_sdk(){
  local sdk="$1"
  [ -x "$sdk/bin/flutter" ] || return 1
  [ -x "$sdk/bin/cache/dart-sdk/bin/dart" ] || return 1
  local fv dv
  fv="$("$sdk/bin/flutter" --version 2>&1 | awk 'NR==1 && $1=="Flutter" {print $2}')"
  dv="$("$sdk/bin/cache/dart-sdk/bin/dart" --version 2>&1 | sed -E 's/^Dart SDK version: ([0-9.]+).*/\1/' | head -1)"
  [ "$fv" = "$FLUTTER_VERSION" ] && [ "$dv" = "$DART_VERSION" ]
}

FOUND_SDK=""
for sdk in "${SDK_CANDIDATES[@]}"; do
  [ -d "$sdk" ] || continue
  if verify_sdk "$sdk"; then FOUND_SDK="$sdk"; break; fi
done

if [ -z "$FOUND_SDK" ]; then
  cat >&2 <<MSG
OFFLINE_TOOLCHAIN_SOURCE_MISSING
No verified Flutter $FLUTTER_VERSION / Dart $DART_VERSION archive or extracted SDK was found.
Searched under: $SEARCH_ROOT
You may set either:
  ELECTROSIM_FLUTTER_ARCHIVE=/absolute/path/to/$OFFICIAL_ARCHIVE
or
  ELECTROSIM_FLUTTER_SDK=/absolute/path/to/flutter
MSG
  exit 68
fi

echo "Verified extracted Flutter SDK: $FOUND_SDK"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/electrosim-flutter-bundle.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
# Archive a directory named flutter/ so extraction matches the official archive layout.
mkdir -p "$TMP/stage"
cp -a "$FOUND_SDK" "$TMP/stage/flutter"
# Remove volatile/project-local caches that are safe to regenerate and can contain absolute paths.
rm -rf "$TMP/stage/flutter/bin/cache/flutter_tools.snapshot.lock" 2>/dev/null || true
( cd "$TMP/stage" && tar -cJf "$LOCAL_TARGET" flutter )
BUNDLE_SHA="$(sha256 "$LOCAL_TARGET")"
python3 - "$META" "$LOCAL_BUNDLE" "$BUNDLE_SHA" "$PLATFORM" "$FLUTTER_VERSION" "$DART_VERSION" <<'PY'
import json,sys
path,name,sha,platform,fv,dv=sys.argv[1:]
data={
  "schemaVersion":1,
  "kind":"repacked-verified-local-sdk",
  "filename":name,
  "sha256":sha,
  "platform":platform,
  "flutterVersion":fv,
  "dartVersion":dv,
}
with open(path,'w',encoding='utf-8') as f:
    json.dump(data,f,indent=2,ensure_ascii=False); f.write('\n')
PY
printf '%s  %s\n' "$BUNDLE_SHA" "$LOCAL_BUNDLE" > "$ROOT/toolchain/SHA256SUMS.txt"
echo "OFFLINE_TOOLCHAIN_BUNDLE_PASS extracted-sdk"
echo "$LOCAL_TARGET"
echo "SHA-256 $BUNDLE_SHA"
