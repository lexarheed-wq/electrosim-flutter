#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=f15_flutter_env.sh
source "$ROOT/tools/f15_flutter_env.sh"
TARGET="${1:?target required}"

"$ROOT/tools/f15_platform_preflight.sh" "$TARGET" >/dev/null
PREP_OUT="$(bash "$ROOT/tools/f17_prepare_release_runner.sh" "$TARGET")"
case "$PREP_OUT" in
  F17_RUNNER_PATH=*) TMP="${PREP_OUT#F17_RUNNER_PATH=}" ;;
  *) echo "F17_RUNNER_PATH_PROTOCOL_ERROR: $PREP_OUT" >&2; exit 69 ;;
esac

APP="$TMP/apps/electrosim"
[ -d "$APP" ] || { echo "F17_RUNNER_PATH_INVALID: $APP" >&2; exit 69; }
cd "$APP"

"$FLUTTER_BIN" analyze
"$FLUTTER_BIN" test test/f0_smoke_test.dart
python3 "$ROOT/tools/f17_apply_lan_platform_config.py" "$APP" "$TARGET" --check

case "$TARGET" in
  macos)
    CMD=("$FLUTTER_BIN" build macos --release)
    ART_GLOB='build/macos/Build/Products/Release/*.app'
    ;;
  windows)
    CMD=("$FLUTTER_BIN" build windows --release)
    ART_GLOB='build/windows/**/runner/Release/electrosim.exe'
    ;;
  linux)
    CMD=("$FLUTTER_BIN" build linux --release)
    ART_GLOB='build/linux/**/release/bundle/electrosim'
    ;;
  android)
    CMD=("$FLUTTER_BIN" build apk --release)
    ART_GLOB='build/app/outputs/flutter-apk/app-release.apk'
    ;;
  ios)
    CMD=("$FLUTTER_BIN" build ios --release --no-codesign)
    ART_GLOB='build/ios/iphoneos/Runner.app'
    ;;
  *)
    echo "unsupported F17 release target: $TARGET" >&2
    exit 2
    ;;
esac

BUILD_LOG="$TMP/f17-r12-$TARGET-build.log"
"${CMD[@]}" > >(tee "$BUILD_LOG") 2> >(tee -a "$BUILD_LOG" >&2)

ART="$(python3 - "$APP" "$ART_GLOB" <<'PY'
from pathlib import Path
import glob
import sys

base = Path(sys.argv[1])
matches = glob.glob(str(base / sys.argv[2]), recursive=True)
if not matches:
    raise SystemExit(3)
print(matches[0])
PY
)"

SHA="$(python3 - "$ART" <<'PY'
from pathlib import Path
import hashlib
import sys

path = Path(sys.argv[1])
digest = hashlib.sha256()
if path.is_dir():
    for file in sorted(x for x in path.rglob("*") if x.is_file()):
        digest.update(file.relative_to(path).as_posix().encode())
        digest.update(b"\0")
        digest.update(file.read_bytes())
else:
    digest.update(path.read_bytes())
print(digest.hexdigest())
PY
)"

FLUTTER_VER="$("$FLUTTER_BIN" --version | head -1 | tr -d '\r')"
DART_VER="$("$DART_BIN" --version 2>&1 | head -1 | tr -d '\r')"
OUT="$ROOT/docs/f17/evidence/r12/$TARGET.json"
mkdir -p "$(dirname "$OUT")"

python3 - "$OUT" "$TARGET" "$FLUTTER_VER" "$DART_VER" "$SHA" "${CMD[*]}" <<'PY'
import datetime
import json
import platform
import sys

out, target, flutter, dart, sha, build_cmd = sys.argv[1:]
data = {
    "schemaVersion": 1,
    "phase": "F17-R12",
    "target": target,
    "status": "PASS",
    "host": {
        "system": platform.system(),
        "release": platform.release(),
        "machine": platform.machine(),
    },
    "flutter": flutter,
    "dart": dart,
    "buildCommand": build_cmd,
    "artifactSha256": sha,
    "smokeTest": "PASS",
    "lanPlatformConfig": "PASS",
    "createdAtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
}
with open(out, "w", encoding="utf-8") as handle:
    json.dump(data, handle, indent=2, sort_keys=True)
    handle.write("\n")
print(json.dumps(data, indent=2, sort_keys=True))
PY

rm -rf "$TMP"
echo "F17_R12_TARGET_QUALIFICATION_PASS $TARGET"
