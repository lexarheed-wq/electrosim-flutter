#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/audit/runtime"; mkdir -p "$AUDIT"
LOG="$AUDIT/f7_gate.log"; RUNTIME="$AUDIT/f7_gate_runtime.json"
exec > >(tee "$LOG") 2>&1
if ! command -v flutter >/dev/null 2>&1 || ! command -v dart >/dev/null 2>&1; then echo "F7_GATE_BLOCKED: Flutter/Dart SDK unavailable" >&2; exit 30; fi
REQUIRED_FLUTTER="$(python3 - "$ROOT/ci/TOOLCHAIN_LOCK.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))['flutter']['version'])
PY
)"
FLUTTER_VERSION_OUTPUT="$(flutter --version)"; ACTUAL_FLUTTER="$(awk 'NR==1 {print $2}' <<< "$FLUTTER_VERSION_OUTPUT")"
if [ "$ACTUAL_FLUTTER" != "$REQUIRED_FLUTTER" ]; then echo "F7_GATE_BLOCKED: Flutter version mismatch required=$REQUIRED_FLUTTER actual=$ACTUAL_FLUTTER" >&2; exit 31; fi
steps=(); run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; steps+=("$name"); }

for SPEC in \
  "f1:electrosim_domain:f1_architecture_guard.dart" \
  "f2:electrosim_topology:f2_architecture_guard.dart" \
  "f3:electrosim_solver_dc:f3_architecture_guard.dart" \
  "f4:electrosim_measurements:f4_architecture_guard.dart" \
  "f6:electrosim_solver_ac:f6_architecture_guard.dart" \
  "f7pv:electrosim_pv:f7_architecture_guard.dart" \
  "f7energy:electrosim_energy:f7_architecture_guard.dart"; do
  IFS=: read -r PHASE PKG GUARD <<< "$SPEC"
  cd "$ROOT/packages/$PKG"
  run_step "$PHASE-dart-pub-get" dart pub get
  FORMAT_TARGETS=(lib test)
  if [ -d tool ]; then FORMAT_TARGETS+=(tool); fi
  run_step "$PHASE-dart-format-normalize" dart format "${FORMAT_TARGETS[@]}"
  run_step "$PHASE-dart-format-check" dart format --output=none --set-exit-if-changed "${FORMAT_TARGETS[@]}"
done

cd "$ROOT"
run_step "tools-dart-format-normalize" dart format "$ROOT/tools/f7_architecture_guard.dart"
run_step "tools-dart-format-check" dart format --output=none --set-exit-if-changed "$ROOT/tools/f7_architecture_guard.dart"
run_step "f0-guard" python3 "$ROOT/tools/f0_guard.py"
run_step "legacy-reference-analysis" python3 "$ROOT/tools/analyze_legacy_reference.py"
run_step "legacy-reference" python3 "$ROOT/tools/verify_legacy_reference.py"
run_step "test-vectors" python3 "$ROOT/tools/validate_test_vectors.py"
run_step "f1-architecture-static" python3 "$ROOT/tools/f1_architecture_guard.py"
run_step "f2-architecture-static" python3 "$ROOT/tools/f2_architecture_guard.py"
run_step "f2-contract-static" python3 "$ROOT/tools/f2_static_contract_check.py"
run_step "f3-architecture-static" python3 "$ROOT/tools/f3_architecture_guard.py"
run_step "f3-contract-static" python3 "$ROOT/tools/f3_static_contract_check.py"
run_step "f4-architecture-static" python3 "$ROOT/tools/f4_architecture_guard.py"
run_step "f4-contract-static" python3 "$ROOT/tools/f4_static_contract_check.py"
run_step "f5-architecture-static" python3 "$ROOT/tools/f5_architecture_guard.py"
run_step "f5-contract-static" python3 "$ROOT/tools/f5_static_contract_check.py"
run_step "f6-architecture-static" python3 "$ROOT/tools/f6_architecture_guard.py"
run_step "f6-contract-static" python3 "$ROOT/tools/f6_static_contract_check.py"
run_step "f7-architecture-static" python3 "$ROOT/tools/f7_architecture_guard.py"
run_step "f7-contract-static" python3 "$ROOT/tools/f7_static_contract_check.py"
run_step "f7-refresh-manifest" python3 "$ROOT/tools/generate_f7_manifest.py"
run_step "f7-verify-manifest" python3 "$ROOT/tools/verify_f7_manifest.py"

for SPEC in \
  "F1:electrosim_domain" \
  "F2:electrosim_topology" \
  "F3:electrosim_solver_dc" \
  "F4:electrosim_measurements"; do
  IFS=: read -r PHASE PKG <<< "$SPEC"
  cd "$ROOT/packages/$PKG"
  run_step "$PHASE-dart-analyze" dart analyze
  run_step "$PHASE-dart-test" dart test
  rm -rf coverage
  run_step "$PHASE-coverage" dart run coverage:test_with_coverage
  run_step "$PHASE-coverage-threshold" python3 "$ROOT/tools/check_lcov.py" coverage/lcov.info 90 "$PHASE"
done

cd "$ROOT/packages/electrosim_solver_ac"
run_step "F5F6-dart-analyze" dart analyze
run_step "F5-regression-test" dart test test/solver_ac1_test.dart
run_step "F6-regression-test" dart test test/solver_ac3_test.dart
run_step "F5F6-dart-test-all" dart test
rm -rf coverage
run_step "F6-coverage" dart run coverage:test_with_coverage
run_step "F6-coverage-threshold" python3 "$ROOT/tools/check_lcov.py" coverage/lcov.info 90 "F6"

cd "$ROOT/packages/electrosim_pv"
run_step "F7-PV-dart-analyze" dart analyze
run_step "F7-PV-dart-test" dart test
rm -rf coverage
run_step "F7-PV-coverage" dart run coverage:test_with_coverage
run_step "F7-PV-coverage-threshold" python3 "$ROOT/tools/check_lcov.py" coverage/lcov.info 90 "F7-PV"

cd "$ROOT/packages/electrosim_energy"
run_step "F7-Energy-dart-analyze" dart analyze
run_step "F7-Energy-dart-test" dart test
rm -rf coverage
run_step "F7-Energy-coverage" dart run coverage:test_with_coverage
run_step "F7-Energy-coverage-threshold" python3 "$ROOT/tools/check_lcov.py" coverage/lcov.info 90 "F7-ENERGY"

cd "$ROOT"
run_step "f2-architecture-guard-dart" dart run tools/f2_architecture_guard.dart
run_step "f3-architecture-guard-dart" dart run tools/f3_architecture_guard.dart
run_step "f4-architecture-guard-dart" dart run tools/f4_architecture_guard.dart
run_step "f5-architecture-guard-dart" dart run tools/f5_architecture_guard.dart
run_step "f6-architecture-guard-dart" dart run tools/f6_architecture_guard.dart
run_step "f7-architecture-guard-dart" dart run tools/f7_architecture_guard.dart

cd "$ROOT/packages/electrosim_solver_dc"
run_step "f3-benchmark-regression" dart run tool/benchmark.dart --output "$AUDIT/f7_f3_benchmark.json"
cd "$ROOT/packages/electrosim_solver_ac"
run_step "f5-benchmark-regression" dart run tool/benchmark.dart --output "$AUDIT/f7_ac1_benchmark.json"
run_step "f6-benchmark-regression" dart run tool/benchmark_ac3.dart --output "$AUDIT/f7_ac3_benchmark.json"
cd "$ROOT/packages/electrosim_pv"
run_step "f7-pv-benchmark-baseline" dart run tool/benchmark.dart --output "$AUDIT/f7_pv_benchmark.json"
cd "$ROOT/packages/electrosim_energy"
run_step "f7-energy-benchmark-baseline" dart run tool/benchmark.dart --output "$AUDIT/f7_energy_benchmark.json"

python3 - "$RUNTIME" "${steps[@]}" <<'PY'
import json,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path
out=Path(sys.argv[1]); steps=sys.argv[2:]
def v(cmd):
 p=subprocess.run(cmd,capture_output=True,text=True); return (p.stdout+p.stderr).strip()
out.write_text(json.dumps({'phase':'F7','status':'PASS','generatedAt':datetime.now(timezone.utc).isoformat(),'flutterVersion':v(['flutter','--version']),'dartVersion':v(['dart','--version']),'passedSteps':steps},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
PY

echo "F7_GATE_PASS"
