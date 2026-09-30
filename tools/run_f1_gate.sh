#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/audit/runtime"
mkdir -p "$AUDIT"
LOG="$AUDIT/f1_gate.log"
RUNTIME="$AUDIT/f1_gate_runtime.json"
exec > >(tee "$LOG") 2>&1

if ! command -v flutter >/dev/null 2>&1 || ! command -v dart >/dev/null 2>&1; then
  echo "F1_GATE_BLOCKED: Flutter/Dart SDK unavailable" >&2
  exit 30
fi
REQUIRED_FLUTTER="$(python3 - "$ROOT/ci/TOOLCHAIN_LOCK.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))['flutter']['version'])
PY
)"
FLUTTER_VERSION_OUTPUT="$(flutter --version)"
ACTUAL_FLUTTER="$(awk 'NR==1 {print $2}' <<< "$FLUTTER_VERSION_OUTPUT")"
if [ "$ACTUAL_FLUTTER" != "$REQUIRED_FLUTTER" ]; then
  echo "F1_GATE_BLOCKED: Flutter version mismatch required=$REQUIRED_FLUTTER actual=$ACTUAL_FLUTTER" >&2
  exit 31
fi

# F0 regression checks: preserve the previously proven shell and frozen legacy reference.
python3 "$ROOT/tools/f0_guard.py"
python3 "$ROOT/tools/analyze_legacy_reference.py"
python3 "$ROOT/tools/verify_legacy_reference.py"
python3 "$ROOT/tools/validate_test_vectors.py"
python3 "$ROOT/tools/f1_architecture_guard.py"
python3 "$ROOT/tools/verify_f1_manifest.py"

steps=()
run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; steps+=("$name"); }

cd "$ROOT/apps/electrosim"
run_step "f0-flutter-pub-get" flutter pub get
run_step "f0-dart-format" dart format --output=none --set-exit-if-changed lib test
run_step "f0-flutter-analyze" flutter analyze
run_step "f0-flutter-test" flutter test

cd "$ROOT/packages/electrosim_domain"
run_step "f1-dart-pub-get" dart pub get
run_step "f1-dart-format" dart format lib test "$ROOT/tools/architecture_guard.dart"
run_step "f1-dart-format-check" dart format --output=none --set-exit-if-changed lib test "$ROOT/tools/architecture_guard.dart"
run_step "f1-dart-analyze" dart analyze
run_step "f1-dart-test" dart test
rm -rf coverage
run_step "f1-coverage" dart run coverage:test_with_coverage
run_step "f1-coverage-threshold" python3 "$ROOT/tools/check_lcov.py" coverage/lcov.info 90

cd "$ROOT"
run_step "f1-architecture-guard-dart" dart run tools/architecture_guard.dart

python3 - "$RUNTIME" "${steps[@]}" <<'PY'
import json,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path
out=Path(sys.argv[1]); steps=sys.argv[2:]
def v(cmd):
    p=subprocess.run(cmd,capture_output=True,text=True)
    return (p.stdout+p.stderr).strip()
out.write_text(json.dumps({
  'phase':'F1','status':'PASS','generatedAt':datetime.now(timezone.utc).isoformat(),
  'flutterVersion':v(['flutter','--version']),'dartVersion':v(['dart','--version']),
  'passedSteps':steps
},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
PY

echo "F1_GATE_PASS"
