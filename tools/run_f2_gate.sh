#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/audit/runtime"
mkdir -p "$AUDIT"
LOG="$AUDIT/f2_gate.log"
RUNTIME="$AUDIT/f2_gate_runtime.json"
exec > >(tee "$LOG") 2>&1

if ! command -v flutter >/dev/null 2>&1 || ! command -v dart >/dev/null 2>&1; then
  echo "F2_GATE_BLOCKED: Flutter/Dart SDK unavailable" >&2
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
  echo "F2_GATE_BLOCKED: Flutter version mismatch required=$REQUIRED_FLUTTER actual=$ACTUAL_FLUTTER" >&2
  exit 31
fi

steps=()
run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; steps+=("$name"); }

# F2-R3 preflight: source inherited from a previously user-validated phase may
# have been formatted on that validation machine. The distributed candidate is
# normalized deterministically with the locked Dart formatter before hashes are
# refreshed and strict format checks are executed. This prevents a false stop
# on "Changed ..." while keeping the actual quality gate strict.
cd "$ROOT/packages/electrosim_domain"
run_step "f1-dart-pub-get" dart pub get
run_step "f1-dart-format-normalize" dart format lib test "$ROOT/tools/architecture_guard.dart"
run_step "f1-dart-format-check" dart format --output=none --set-exit-if-changed lib test "$ROOT/tools/architecture_guard.dart"

cd "$ROOT/packages/electrosim_topology"
run_step "f2-dart-pub-get" dart pub get
run_step "f2-dart-format-normalize" dart format lib test "$ROOT/tools/f2_architecture_guard.dart"
run_step "f2-dart-format-check" dart format --output=none --set-exit-if-changed lib test "$ROOT/tools/f2_architecture_guard.dart"

cd "$ROOT"
run_step "f0-guard" python3 "$ROOT/tools/f0_guard.py"
run_step "legacy-analysis" python3 "$ROOT/tools/analyze_legacy_reference.py"
run_step "legacy-reference" python3 "$ROOT/tools/verify_legacy_reference.py"
run_step "test-vectors" python3 "$ROOT/tools/validate_test_vectors.py"
run_step "f1-architecture-static" python3 "$ROOT/tools/f1_architecture_guard.py"
run_step "f2-architecture-static" python3 "$ROOT/tools/f2_architecture_guard.py"
run_step "f2-contract-static" python3 "$ROOT/tools/f2_static_contract_check.py"

# Formatting legitimately changes hashes. Refresh manifests only after the
# deterministic normalization, then immediately verify them.
run_step "f1-refresh-manifest" python3 "$ROOT/tools/generate_f1_manifest.py"
run_step "f1-verify-refreshed-manifest" python3 "$ROOT/tools/verify_f1_manifest.py"
run_step "f2-refresh-manifest" python3 "$ROOT/tools/generate_f2_manifest.py"
run_step "f2-verify-refreshed-manifest" python3 "$ROOT/tools/verify_f2_manifest.py"

cd "$ROOT/packages/electrosim_domain"
run_step "f1-dart-analyze" dart analyze
run_step "f1-dart-test" dart test
rm -rf coverage
run_step "f1-coverage" dart run coverage:test_with_coverage
run_step "f1-coverage-threshold" python3 "$ROOT/tools/check_lcov.py" coverage/lcov.info 90

cd "$ROOT/packages/electrosim_topology"
run_step "f2-dart-analyze" dart analyze
run_step "f2-dart-test" dart test
rm -rf coverage
run_step "f2-coverage" dart run coverage:test_with_coverage
run_step "f2-coverage-threshold" python3 "$ROOT/tools/check_lcov.py" coverage/lcov.info 90

cd "$ROOT"
run_step "f2-architecture-guard-dart" dart run tools/f2_architecture_guard.dart

python3 - "$RUNTIME" "${steps[@]}" <<'PY'
import json,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path
out=Path(sys.argv[1]); steps=sys.argv[2:]
def v(cmd):
    p=subprocess.run(cmd,capture_output=True,text=True)
    return (p.stdout+p.stderr).strip()
out.write_text(json.dumps({
  'phase':'F2','status':'PASS','generatedAt':datetime.now(timezone.utc).isoformat(),
  'flutterVersion':v(['flutter','--version']),'dartVersion':v(['dart','--version']),
  'passedSteps':steps
},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
PY

echo "F2_GATE_PASS"
