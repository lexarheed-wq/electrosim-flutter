#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/audit"
RUNTIME="$AUDIT/runtime/f9_final_gate_runtime.json"
APPROVAL="$ROOT/docs/f9/F9_GOLDEN_APPROVAL.json"
GOLDEN_DIR="$ROOT/apps/electrosim/test/goldens"
mkdir -p "$AUDIT/runtime" "$GOLDEN_DIR"
steps=()
run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; steps+=("$name"); }

export FLUTTER_SUPPRESS_ANALYTICS=true
run_step "f9-f8-core-freeze" python3 "$ROOT/tools/f9_f8_core_freeze_check.py"
run_step "f9-architecture" python3 "$ROOT/tools/f9_architecture_guard.py"
run_step "f9-static-contract" python3 "$ROOT/tools/f9_static_contract_check.py"
run_step "f9-accessibility-audit" python3 "$ROOT/tools/f9_accessibility_audit.py"
run_step "f9-ux-canvas-static" python3 "$ROOT/tools/f9_ux_canvas_static_check.py"
run_step "f9-status-bar-static" python3 "$ROOT/tools/f9_status_bar_static_check.py"
run_step "f9-test-vectors" python3 "$ROOT/tools/validate_test_vectors.py"
run_step "f9-final-preflight" python3 "$ROOT/tools/f9_final_preflight.py"

cd "$ROOT/packages/electrosim_ui_kit"
run_step "F9-ui-kit-analyze" flutter analyze
run_step "F9-ui-kit-test" flutter test

cd "$ROOT/packages/electrosim_canvas"
run_step "F8-canvas-regression-analyze" flutter analyze
run_step "F8-canvas-regression-test" flutter test test/viewport_controller_test.dart test/hit_test_engine_test.dart test/simulator_canvas_test.dart

cd "$ROOT/apps/electrosim"
run_step "F9-app-analyze" flutter analyze
run_step "F9-app-functional-tests" flutter test \
  test/f0_smoke_test.dart \
  test/f9_auto_placement_test.dart \
  test/f9_element_editor_test.dart \
  test/f9_wiring_policy_test.dart \
  test/f9_canvas_interaction_test.dart \
  test/f9_shell_test.dart

for PKG in electrosim_domain electrosim_topology electrosim_solver_dc electrosim_solver_ac electrosim_measurements electrosim_pv electrosim_energy; do
  cd "$ROOT/packages/$PKG"
  run_step "regression-$PKG-pub-get" dart pub get
  run_step "regression-$PKG-analyze" dart analyze
  run_step "regression-$PKG-test" dart test
done

cd "$ROOT/apps/electrosim"
EXPECTED=(
  f9_compact_base.png f9_compact_palette.png f9_compact_properties.png
  f9_medium_base.png f9_medium_palette.png f9_medium_properties.png
  f9_expanded_base.png f9_expanded_palette.png f9_expanded_properties.png
  f9_compact_student_diagnostic.png
)
missing=0
for f in "${EXPECTED[@]}"; do
  [ -f "$GOLDEN_DIR/$f" ] || missing=1
done

if [ "$missing" -eq 1 ] || [ ! -f "$APPROVAL" ]; then
  run_step "F9-golden-generate" flutter test --update-goldens test/f9_goldens_test.dart
  cd "$ROOT"
  run_step "f9-refresh-manifest" python3 "$ROOT/tools/generate_f9_manifest.py"
  run_step "f9-verify-manifest" python3 "$ROOT/tools/verify_f9_manifest.py"
  echo "F9_GATE_GOLDEN_REVIEW_REQUIRED"
  echo "Review: ./review_f9_goldens.sh"
  echo "Approve: python3 tools/approve_f9_goldens.py --approve"
  echo "Then rerun: ./validate.sh"
  exit 0
fi

run_step "F9-golden-regression" flutter test test/f9_goldens_test.dart
cd "$ROOT"
run_step "F9-golden-approval" python3 "$ROOT/tools/approve_f9_goldens.py" --verify
run_step "f9-refresh-manifest" python3 "$ROOT/tools/generate_f9_manifest.py"
run_step "f9-verify-manifest" python3 "$ROOT/tools/verify_f9_manifest.py"

python3 - "$RUNTIME" "${steps[@]}" <<'PY'
import json,subprocess,sys
from datetime import datetime,timezone
from pathlib import Path
out=Path(sys.argv[1]); steps=sys.argv[2:]
def v(cmd):
 p=subprocess.run(cmd,capture_output=True,text=True); return (p.stdout+p.stderr).strip()
out.write_text(json.dumps({
 'phase':'F9-FINAL','status':'PASS','automatedChecksPassed':True,'goldensApproved':True,
 'generatedAt':datetime.now(timezone.utc).isoformat(),
 'flutterVersion':v(['flutter','--version']),'dartVersion':v(['dart','--version']),
 'passedSteps':steps
},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
PY

echo "F9_GATE_PASS"
