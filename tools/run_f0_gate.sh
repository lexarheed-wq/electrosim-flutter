#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/audit/runtime"
mkdir -p "$AUDIT"
LOG="$AUDIT/f0_gate.log"
RUNTIME="$AUDIT/f0_gate_runtime.json"
export F0_AUDIT_DIR="$AUDIT"
exec > >(tee "$LOG") 2>&1

python3 "$ROOT/tools/toolchain_probe.py"
python3 "$ROOT/tools/f0_guard.py"
python3 "$ROOT/tools/analyze_legacy_reference.py"
python3 "$ROOT/tools/verify_legacy_reference.py"
python3 "$ROOT/tools/validate_test_vectors.py"
python3 "$ROOT/tools/generate_f0_manifest.py"
python3 "$ROOT/tools/verify_f0_manifest.py"
python3 "$ROOT/tools/test_f0_tooling.py"

if ! command -v flutter >/dev/null 2>&1; then
  echo "F0_GATE_BLOCKED: Flutter SDK unavailable" >&2
  python3 - "$RUNTIME" <<'PY'
import json,sys
from datetime import datetime,timezone
from pathlib import Path
Path(sys.argv[1]).write_text(json.dumps({"phase":"F0","status":"BLOCKED","reason":"Flutter SDK unavailable","generatedAt":datetime.now(timezone.utc).isoformat()},indent=2)+"\n")
PY
  exit 20
fi
if ! command -v dart >/dev/null 2>&1; then
  echo "F0_GATE_BLOCKED: Dart SDK unavailable" >&2
  exit 21
fi

REQUIRED_FLUTTER="$(python3 - "$ROOT/ci/TOOLCHAIN_LOCK.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))['flutter']['version'])
PY
)"
FLUTTER_VERSION_OUTPUT="$(flutter --version)"
ACTUAL_FLUTTER="$(awk 'NR==1 {print $2}' <<< "$FLUTTER_VERSION_OUTPUT")"
if [ "$ACTUAL_FLUTTER" != "$REQUIRED_FLUTTER" ]; then
  echo "F0_GATE_BLOCKED: Flutter version mismatch required=$REQUIRED_FLUTTER actual=$ACTUAL_FLUTTER" >&2
  exit 22
fi

cd "$ROOT/apps/electrosim"
steps=()
run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; steps+=("$name"); }
# Resolve package metadata before invoking the formatter. On the target Monterey
# Mac, R6 reached Dart successfully but dart format ran before pub get, which
# caused package-resolution warnings and exposed an unformatted F0 source file.
run_step "flutter-pub-get" flutter pub get
run_step "dart-format" dart format --output=none --set-exit-if-changed lib test
run_step "flutter-analyze" flutter analyze
run_step "flutter-test" flutter test

cd "$ROOT"
python3 - "$RUNTIME" "${steps[@]}" <<'PY'
import json,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path
out=Path(sys.argv[1]); steps=sys.argv[2:]
def v(cmd):
    p=subprocess.run(cmd,capture_output=True,text=True)
    return (p.stdout+p.stderr).strip()
out.write_text(json.dumps({"phase":"F0","status":"PASS","generatedAt":datetime.now(timezone.utc).isoformat(),"flutterVersion":v(["flutter","--version"]),"dartVersion":v(["dart","--version"]),"passedSteps":steps},indent=2,ensure_ascii=False)+"\n")
PY

echo "F0_GATE_PASS"
