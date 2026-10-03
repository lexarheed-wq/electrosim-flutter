#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
LOCK="$ROOT/ci/TOOLCHAIN_LOCK.json"
RUNTIME="$ROOT/audit/runtime/f9_final_gate_runtime.json"
MODE="${1:-final}"

if [ "$MODE" = "--pre-gate" ]; then
  echo "F9 visual pre-validation mode: gate approval is not required."
  python3 "$ROOT/tools/f9_f8_core_freeze_check.py"
  python3 "$ROOT/tools/f9_architecture_guard.py"
  python3 "$ROOT/tools/f9_static_contract_check.py"
  python3 "$ROOT/tools/f9_accessibility_audit.py"
  python3 "$ROOT/tools/f9_ux_canvas_static_check.py"
  python3 "$ROOT/tools/f9_final_preflight.py"
elif [ "$MODE" = "final" ]; then
  python3 - "$RUNTIME" <<'PY'
import json,sys
from pathlib import Path
p=Path(sys.argv[1])
if not p.is_file():
    print('Visual launch blocked: F9 final gate has not passed. Use ./run_visual.sh --pre-gate for pre-validation.', file=sys.stderr)
    raise SystemExit(41)
data=json.loads(p.read_text(encoding='utf-8'))
if data.get('status') != 'PASS' or not data.get('goldensApproved'):
    print('Visual launch blocked: F9 final gate/golden approval is incomplete. Use ./run_visual.sh --pre-gate for pre-validation.', file=sys.stderr)
    raise SystemExit(41)
print('F9 final gate state: PASS')
PY
else
  echo "Usage: ./run_visual.sh [--pre-gate]" >&2
  exit 40
fi

REQUIRED_FLUTTER="$(python3 - "$LOCK" <<'PY'
import json,sys
print(json.load(open(sys.argv[1],encoding='utf-8'))['flutter']['version'])
PY
)"

find_flutter() {
  local candidate output actual
  for candidate in "$ROOT/.toolchain/flutter/bin/flutter" "$ROOT"/../ElectroSim-Flutter-F*-VENTURA-CANDIDATE/.toolchain/flutter/bin/flutter "$ROOT"/../ElectroSim-Flutter-F*-MONTEREY-CANDIDATE/.toolchain/flutter/bin/flutter; do
    [ -x "$candidate" ] || continue
    output="$($candidate --version 2>&1 || true)"
    actual="$(awk 'NR==1 && $1=="Flutter" {print $2}' <<< "$output")"
    if [ "$actual" = "$REQUIRED_FLUTTER" ]; then echo "$candidate"; return 0; fi
  done
  if command -v flutter >/dev/null 2>&1; then
    candidate="$(command -v flutter)"; output="$($candidate --version 2>&1 || true)"
    actual="$(awk 'NR==1 && $1=="Flutter" {print $2}' <<< "$output")"
    if [ "$actual" = "$REQUIRED_FLUTTER" ]; then echo "$candidate"; return 0; fi
  fi
  return 1
}

FLUTTER_BIN="$(find_flutter || true)"
if [ -z "$FLUTTER_BIN" ]; then echo "Flutter $REQUIRED_FLUTTER not found. Run ./validate.sh first." >&2; exit 42; fi
export PATH="$(dirname "$FLUTTER_BIN"):$PATH"
export FLUTTER_SUPPRESS_ANALYTICS=true

if [ "$(uname -s)" != "Darwin" ]; then echo "run_visual.sh targets the validated macOS workflow." >&2; exit 44; fi
if ! command -v xcodebuild >/dev/null 2>&1; then echo "Xcode is unavailable." >&2; exit 45; fi

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/electrosim-f9-final-visual.XXXXXX")"
cleanup(){ rm -rf "$TMP_ROOT"; }
trap cleanup EXIT INT TERM
mkdir -p "$TMP_ROOT/apps"
cp -R "$ROOT/apps/electrosim" "$TMP_ROOT/apps/electrosim"
cp -R "$ROOT/packages" "$TMP_ROOT/packages"
find "$TMP_ROOT" -type d \( -name .dart_tool -o -name build -o -name coverage \) -prune -exec rm -rf {} + 2>/dev/null || true
find "$TMP_ROOT" -name pubspec.lock -delete 2>/dev/null || true
APP="$TMP_ROOT/apps/electrosim"
cd "$APP"
echo "Preparing disposable F9 final macOS runner in: $TMP_ROOT"
"$FLUTTER_BIN" create --platforms=macos --project-name electrosim . >/dev/null
cp "$ROOT/apps/electrosim/pubspec.yaml" "$APP/pubspec.yaml"
python3 "$ROOT/tools/f17_apply_lan_platform_config.py" "$APP" macos
python3 "$ROOT/tools/f17_apply_lan_platform_config.py" "$APP" macos --check
"$FLUTTER_BIN" pub get
echo "Launching ElectroSim F9 FINAL. Source candidate remains untouched."
echo "Flutter run keys: r=hot reload, R=hot restart, q=quit"
"$FLUTTER_BIN" run -d macos
