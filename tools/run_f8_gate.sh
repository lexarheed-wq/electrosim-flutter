#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/audit/f8"; mkdir -p "$AUDIT" "$ROOT/audit/runtime"
LOG="$ROOT/audit/runtime/f8_gate.log"; RUNTIME="$ROOT/audit/runtime/f8_gate_runtime.json"
exec > >(tee "$LOG") 2>&1
if ! command -v flutter >/dev/null 2>&1 || ! command -v dart >/dev/null 2>&1; then echo "F8_GATE_BLOCKED: Flutter/Dart SDK unavailable" >&2; exit 30; fi
REQUIRED_FLUTTER="$(python3 - "$ROOT/ci/TOOLCHAIN_LOCK.json" <<'PY'
import json,sys
print(json.load(open(sys.argv[1]))['flutter']['version'])
PY
)"
FLUTTER_VERSION_OUTPUT="$(flutter --version)"; ACTUAL_FLUTTER="$(awk 'NR==1 {print $2}' <<< "$FLUTTER_VERSION_OUTPUT")"
if [ "$ACTUAL_FLUTTER" != "$REQUIRED_FLUTTER" ]; then echo "F8_GATE_BLOCKED: Flutter version mismatch required=$REQUIRED_FLUTTER actual=$ACTUAL_FLUTTER" >&2; exit 31; fi
steps=(); run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; steps+=("$name"); }

# Normalize and resolve every package touched by F1-F8. F8 must not hide a regression.
for SPEC in \
  "f1:electrosim_domain:dart" \
  "f2:electrosim_topology:dart" \
  "f3:electrosim_solver_dc:dart" \
  "f4:electrosim_measurements:dart" \
  "f6:electrosim_solver_ac:dart" \
  "f7pv:electrosim_pv:dart" \
  "f7energy:electrosim_energy:dart" \
  "f8:electrosim_canvas:flutter"; do
  IFS=: read -r PHASE PKG TOOL <<< "$SPEC"
  cd "$ROOT/packages/$PKG"
  if [ "$TOOL" = "flutter" ]; then run_step "$PHASE-pub-get" flutter pub get; else run_step "$PHASE-pub-get" dart pub get; fi
  FORMAT_TARGETS=(lib test)
  if [ -d tool ]; then FORMAT_TARGETS+=(tool); fi
  run_step "$PHASE-format-normalize" dart format "${FORMAT_TARGETS[@]}"
  run_step "$PHASE-format-check" dart format --output=none --set-exit-if-changed "${FORMAT_TARGETS[@]}"
done

cd "$ROOT/apps/electrosim"
run_step "f8-app-pub-get" flutter pub get
run_step "f8-app-format-normalize" dart format lib test
run_step "f8-app-format-check" dart format --output=none --set-exit-if-changed lib test

cd "$ROOT"
run_step "f8-tools-format-normalize" dart format "$ROOT/tools/f8_architecture_guard.dart"
run_step "f8-tools-format-check" dart format --output=none --set-exit-if-changed "$ROOT/tools/f8_architecture_guard.dart"
run_step "f0-guard" python3 "$ROOT/tools/f0_guard.py"
# The distributable intentionally excludes runtime audit outputs. Rebuild the
# immutable legacy-reference analysis before verifying it, so a clean unzip is
# self-contained and the one-command gate does not depend on authoring artifacts.
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
run_step "f8-architecture-static" python3 "$ROOT/tools/f8_architecture_guard.py"
run_step "f8-contract-static" python3 "$ROOT/tools/f8_static_contract_check.py"
run_step "f8-deep-static-audit" python3 "$ROOT/tools/f8_deep_static_audit.py"
run_step "f8-r7-tooling-tests" python3 -m unittest "$ROOT/tools/test_f8_r7_tooling.py"

# Cumulative pure-Dart regression gates.
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

# F8 rendering + gestures.
cd "$ROOT/packages/electrosim_canvas"
run_step "F8-flutter-analyze" flutter analyze
run_step "F8-widget-gestures" flutter test test/viewport_controller_test.dart test/hit_test_engine_test.dart test/simulator_canvas_test.dart

GOLDEN_DIR="$ROOT/packages/electrosim_canvas/test/goldens"
GOLDEN_BASELINE="$ROOT/docs/f8/F8_GOLDEN_BASELINE.json"
GOLDEN_REVIEW_REQUIRED=0
if [ ! -f "$GOLDEN_DIR/canvas_compact.png" ] || [ ! -f "$GOLDEN_DIR/canvas_medium.png" ] || [ ! -f "$GOLDEN_DIR/canvas_expanded.png" ]; then
  echo "=== f8-golden-baseline-create ==="
  flutter test --update-goldens test/simulator_canvas_golden_test.dart
  steps+=("f8-golden-baseline-create")
  GOLDEN_REVIEW_REQUIRED=1
fi
run_step "f8-golden-verify" flutter test test/simulator_canvas_golden_test.dart
if [ -f "$GOLDEN_BASELINE" ]; then
  run_step "f8-golden-baseline-verify" python3 "$ROOT/tools/verify_f8_golden_baseline.py"
else
  GOLDEN_REVIEW_REQUIRED=1
  echo "F8 golden baseline has not yet been human-approved."
fi

echo "=== f8-performance ==="
flutter test test/canvas_performance_test.dart 2>&1 | tee "$AUDIT/f8_canvas_performance.log"
steps+=("f8-performance")

cd "$ROOT/apps/electrosim"
run_step "F8-app-analyze" flutter analyze
run_step "F8-app-test" flutter test

cd "$ROOT"
run_step "f2-architecture-guard-dart" dart run tools/f2_architecture_guard.dart
run_step "f3-architecture-guard-dart" dart run tools/f3_architecture_guard.dart
run_step "f4-architecture-guard-dart" dart run tools/f4_architecture_guard.dart
run_step "f5-architecture-guard-dart" dart run tools/f5_architecture_guard.dart
run_step "f6-architecture-guard-dart" dart run tools/f6_architecture_guard.dart
run_step "f7-architecture-guard-dart" dart run tools/f7_architecture_guard.dart
run_step "f8-architecture-guard-dart" dart run tools/f8_architecture_guard.dart
run_step "f8-ui-audit" python3 "$ROOT/tools/generate_f8_audit.py" "$AUDIT/f8_canvas_performance.log"
run_step "f8-refresh-manifest" python3 "$ROOT/tools/generate_f8_manifest.py"
run_step "f8-verify-manifest" python3 "$ROOT/tools/verify_f8_manifest.py"

if [ "$GOLDEN_REVIEW_REQUIRED" -eq 1 ]; then
  python3 - "$RUNTIME" "${steps[@]}" <<'PY'
import json,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path
out=Path(sys.argv[1]); steps=sys.argv[2:]
def v(cmd):
 p=subprocess.run(cmd,capture_output=True,text=True); return (p.stdout+p.stderr).strip()
out.write_text(json.dumps({'phase':'F8','status':'GOLDEN_REVIEW_REQUIRED','automatedChecksPassed':True,'generatedAt':datetime.now(timezone.utc).isoformat(),'flutterVersion':v(['flutter','--version']),'dartVersion':v(['dart','--version']),'passedSteps':steps},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
PY
  echo "F8_GATE_GOLDEN_REVIEW_REQUIRED"
  echo "Review the three generated PNG files in packages/electrosim_canvas/test/goldens/."
  echo "You may launch the Canvas now with: ./run_visual.sh"
  echo "After visual approval run: python3 tools/approve_f8_goldens.py --approve"
  echo "Then rerun: ./validate.sh"
  exit 42
fi

python3 - "$RUNTIME" "${steps[@]}" <<'PY'
import json,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path
out=Path(sys.argv[1]); steps=sys.argv[2:]
def v(cmd):
 p=subprocess.run(cmd,capture_output=True,text=True); return (p.stdout+p.stderr).strip()
out.write_text(json.dumps({'phase':'F8','status':'PASS','automatedChecksPassed':True,'generatedAt':datetime.now(timezone.utc).isoformat(),'flutterVersion':v(['flutter','--version']),'dartVersion':v(['dart','--version']),'passedSteps':steps},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
PY

echo "F8_GATE_PASS"
