#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=f15_flutter_env.sh
source "$ROOT/tools/f15_flutter_env.sh"
TARGET="${1:?target required}"
"$ROOT/tools/f15_platform_preflight.sh" "$TARGET" >/dev/null
OUT="$ROOT/docs/f15/evidence/$TARGET.json"
mkdir -p "$(dirname "$OUT")"
HOST="$(uname -s)"
case "$TARGET" in
  macos) [ "$HOST" = Darwin ] || { echo "macOS target requires Darwin host" >&2; exit 2; } ;;
  ios) [ "$HOST" = Darwin ] || { echo "iOS target requires Darwin host" >&2; exit 2; } ;;
  linux) [ "$HOST" = Linux ] || { echo "Linux target requires Linux host" >&2; exit 2; } ;;
  windows) [[ "$HOST" == MINGW* || "$HOST" == MSYS* || "$HOST" == CYGWIN* || "${OS:-}" == Windows_NT ]] || { echo "Windows target requires Windows host" >&2; exit 2; } ;;
  android|web) ;;
  *) echo "unsupported target: $TARGET" >&2; exit 2;;
esac
PREP_OUT="$("$ROOT/tools/f15_prepare_runner.sh" "$TARGET")"
case "$PREP_OUT" in
  F15_RUNNER_PATH=*) TMP="${PREP_OUT#F15_RUNNER_PATH=}" ;;
  *) echo "F15_RUNNER_PATH_PROTOCOL_ERROR: $PREP_OUT" >&2; exit 69 ;;
esac
APP="$TMP/apps/electrosim"
[ -d "$APP" ] || { echo "F15_RUNNER_PATH_INVALID: $APP" >&2; exit 69; }
python3 "$ROOT/tools/f17_verify_lan_platform_config.py" "$APP" "$TARGET"
cd "$APP"
"$FLUTTER_BIN" analyze
"$FLUTTER_BIN" test test/f0_smoke_test.dart
case "$TARGET" in
  macos) CMD=("$FLUTTER_BIN" build macos --debug); ART_GLOB='build/macos/Build/Products/Debug/*.app' ;;
  windows) CMD=("$FLUTTER_BIN" build windows --debug); ART_GLOB='build/windows/**/runner/Debug/*' ;;
  linux) CMD=("$FLUTTER_BIN" build linux --debug); ART_GLOB='build/linux/**/debug/bundle/electrosim' ;;
  android) CMD=("$FLUTTER_BIN" build apk --debug); ART_GLOB='build/app/outputs/flutter-apk/app-debug.apk' ;;
  ios) CMD=("$FLUTTER_BIN" build ios --debug --no-codesign); ART_GLOB='build/ios/iphoneos/Runner.app' ;;
  web) CMD=("$FLUTTER_BIN" build web); ART_GLOB='build/web/main.dart.js' ;;
esac
BUILD_LOG="$TMP/f15-${TARGET}-build.log"
set +e
"${CMD[@]}" > >(tee "$BUILD_LOG") 2> >(tee -a "$BUILD_LOG" >&2)
BUILD_RC=$?
set -e
if [ "$BUILD_RC" -ne 0 ]; then
  if [ "$TARGET" = "ios" ] && grep -Eqi "iOS [0-9.]+ is not installed|Unable to find a destination matching the provided destination specifier|required platform.*not installed|download and install the platform" "$BUILD_LOG"; then
    rm -rf "$TMP"
    echo "F15_TARGET_UNAVAILABLE ios ios-platform-runtime-missing"
    exit 3
  fi
  echo "F15_TARGET_BUILD_FAILED $TARGET rc=$BUILD_RC" >&2
  exit "$BUILD_RC"
fi
ART="$(python3 - "$APP" "$ART_GLOB" <<'PY'
from pathlib import Path
import glob,sys
base=Path(sys.argv[1]); pat=sys.argv[2]
ms=glob.glob(str(base/pat),recursive=True)
if not ms: raise SystemExit(3)
print(ms[0])
PY
)"
if [ "$TARGET" = "android" ]; then
  python3 "$ROOT/tools/f17_verify_android_apk.py" "$ART"
fi
SHA="$(python3 - "$ART" <<'PY'
from pathlib import Path
import hashlib,sys
p=Path(sys.argv[1]); h=hashlib.sha256()
if p.is_dir():
    for f in sorted(x for x in p.rglob('*') if x.is_file()):
        h.update(f.relative_to(p).as_posix().encode()); h.update(b'\0'); h.update(f.read_bytes())
else: h.update(p.read_bytes())
print(h.hexdigest())
PY
)"
FLUTTER_VER="$("$FLUTTER_BIN" --version | head -1 | tr -d '\r')"
DART_VER="$("$DART_BIN" --version 2>&1 | head -1 | tr -d '\r')"
python3 - "$OUT" "$TARGET" "$HOST" "$FLUTTER_VER" "$DART_VER" "$SHA" "${CMD[*]}" <<'PY'
import json,platform,sys,datetime
out,target,host,flutter,dart,sha,buildcmd=sys.argv[1:]
data={'schemaVersion':1,'phase':'F17-R12','target':target,'status':'PASS','host':{'uname':host,'system':platform.system(),'release':platform.release(),'machine':platform.machine()},'flutter':flutter,'dart':dart,'buildCommand':buildcmd,'artifactSha256':sha,'smokeTest':'PASS','offlineCoreSmoke':'PASS','createdAtUtc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
open(out,'w',encoding='utf-8').write(json.dumps(data,indent=2,sort_keys=True)+'\n')
print(json.dumps(data,indent=2))
PY
rm -rf "$TMP"
echo "F15_TARGET_QUALIFICATION_PASS $TARGET"
