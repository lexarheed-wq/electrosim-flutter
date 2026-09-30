#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/audit/runtime"; mkdir -p "$AUDIT"
LOG="$AUDIT/f3_gate.log"; RUNTIME="$AUDIT/f3_gate_runtime.json"
exec > >(tee "$LOG") 2>&1
if ! command -v flutter >/dev/null 2>&1 || ! command -v dart >/dev/null 2>&1; then echo "F3_GATE_BLOCKED: Flutter/Dart SDK unavailable" >&2; exit 30; fi
REQUIRED_FLUTTER="$(python3 - "$ROOT/ci/TOOLCHAIN_LOCK.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))['flutter']['version'])
PY
)"
FLUTTER_VERSION_OUTPUT="$(flutter --version)"; ACTUAL_FLUTTER="$(awk 'NR==1 {print $2}' <<< "$FLUTTER_VERSION_OUTPUT")"
if [ "$ACTUAL_FLUTTER" != "$REQUIRED_FLUTTER" ]; then echo "F3_GATE_BLOCKED: Flutter version mismatch required=$REQUIRED_FLUTTER actual=$ACTUAL_FLUTTER" >&2; exit 31; fi
steps=(); run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; steps+=("$name"); }

# Normalize all authored Dart with the locked formatter, then apply strict checks.
for SPEC in "f1:electrosim_domain:architecture_guard.dart" "f2:electrosim_topology:f2_architecture_guard.dart" "f3:electrosim_solver_dc:f3_architecture_guard.dart"; do
  IFS=: read -r PHASE PKG GUARD <<< "$SPEC"
  cd "$ROOT/packages/$PKG"
  run_step "$PHASE-dart-pub-get" dart pub get
  FORMAT_TARGETS=(lib test "$ROOT/tools/$GUARD")
  if [ -d tool ]; then FORMAT_TARGETS+=(tool); fi
  run_step "$PHASE-dart-format-normalize" dart format "${FORMAT_TARGETS[@]}"
  run_step "$PHASE-dart-format-check" dart format --output=none --set-exit-if-changed "${FORMAT_TARGETS[@]}"
done

cd "$ROOT"
run_step "f0-guard" python3 "$ROOT/tools/f0_guard.py"
run_step "legacy-analysis" python3 "$ROOT/tools/analyze_legacy_reference.py"
run_step "legacy-reference" python3 "$ROOT/tools/verify_legacy_reference.py"
run_step "test-vectors" python3 "$ROOT/tools/validate_test_vectors.py"
run_step "f1-architecture-static" python3 "$ROOT/tools/f1_architecture_guard.py"
run_step "f2-architecture-static" python3 "$ROOT/tools/f2_architecture_guard.py"
run_step "f2-contract-static" python3 "$ROOT/tools/f2_static_contract_check.py"
run_step "f3-architecture-static" python3 "$ROOT/tools/f3_architecture_guard.py"
run_step "f3-contract-static" python3 "$ROOT/tools/f3_static_contract_check.py"
run_step "f3-refresh-manifest" python3 "$ROOT/tools/generate_f3_manifest.py"
run_step "f3-verify-manifest" python3 "$ROOT/tools/verify_f3_manifest.py"

for SPEC in "F1:electrosim_domain" "F2:electrosim_topology" "F3:electrosim_solver_dc"; do
  IFS=: read -r PHASE PKG <<< "$SPEC"
  cd "$ROOT/packages/$PKG"
  run_step "$PHASE-dart-analyze" dart analyze
  run_step "$PHASE-dart-test" dart test
  rm -rf coverage
  run_step "$PHASE-coverage" dart run coverage:test_with_coverage
  run_step "$PHASE-coverage-threshold" python3 "$ROOT/tools/check_lcov.py" coverage/lcov.info 90 "$PHASE"
done

cd "$ROOT"
run_step "f2-architecture-guard-dart" dart run tools/f2_architecture_guard.dart
run_step "f3-architecture-guard-dart" dart run tools/f3_architecture_guard.dart
cd "$ROOT/packages/electrosim_solver_dc"
run_step "f3-benchmark-baseline" dart run tool/benchmark.dart --output "$AUDIT/f3_benchmark.json"

python3 - "$RUNTIME" "${steps[@]}" <<'PY'
import json,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path
out=Path(sys.argv[1]); steps=sys.argv[2:]
def v(cmd):
 p=subprocess.run(cmd,capture_output=True,text=True); return (p.stdout+p.stderr).strip()
out.write_text(json.dumps({'phase':'F3','status':'PASS','generatedAt':datetime.now(timezone.utc).isoformat(),'flutterVersion':v(['flutter','--version']),'dartVersion':v(['dart','--version']),'passedSteps':steps},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
PY

echo "F3_GATE_PASS"
