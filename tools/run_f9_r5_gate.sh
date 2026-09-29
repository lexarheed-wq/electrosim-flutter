#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT="$ROOT/audit"
RUNTIME="$AUDIT/runtime/f9_r5_gate_runtime.json"
mkdir -p "$AUDIT/runtime"
steps=()
run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; steps+=("$name"); }

export FLUTTER_SUPPRESS_ANALYTICS=true
run_step "f9-f8-core-freeze" python3 "$ROOT/tools/f9_f8_core_freeze_check.py"
run_step "f9-architecture" python3 "$ROOT/tools/f9_architecture_guard.py"
run_step "f9-static-contract" python3 "$ROOT/tools/f9_static_contract_check.py"
run_step "f9-test-vectors" python3 "$ROOT/tools/validate_test_vectors.py"

# Validate the new UI package first.
cd "$ROOT/packages/electrosim_ui_kit"
run_step "F9-ui-kit-analyze" flutter analyze
run_step "F9-ui-kit-test" flutter test

# F8 interaction regression: production package is frozen and these tests prove runtime compatibility.
cd "$ROOT/packages/electrosim_canvas"
run_step "F8-canvas-regression-analyze" flutter analyze
run_step "F8-canvas-regression-test" flutter test test/viewport_controller_test.dart test/hit_test_engine_test.dart test/simulator_canvas_test.dart

# App composition / responsive shell.
cd "$ROOT/apps/electrosim"
run_step "F9-app-analyze" flutter analyze
run_step "F9-app-test" flutter test

# Pure-Dart domain regressions. A fresh extracted candidate intentionally contains no .dart_tool/package_config.json,
# therefore each package MUST resolve dependencies before analyze/test. This mirrors the validated F1-F8 gates.
for PKG in electrosim_domain electrosim_topology electrosim_solver_dc electrosim_solver_ac electrosim_measurements electrosim_pv electrosim_energy; do
  cd "$ROOT/packages/$PKG"
  run_step "regression-$PKG-pub-get" dart pub get
  run_step "regression-$PKG-analyze" dart analyze
  run_step "regression-$PKG-test" dart test
done

cd "$ROOT"
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
 'phase':'F9-R5','status':'PASS','automatedChecksPassed':True,
 'generatedAt':datetime.now(timezone.utc).isoformat(),
 'flutterVersion':v(['flutter','--version']),'dartVersion':v(['dart','--version']),
 'passedSteps':steps
},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
PY

echo "F9_R5_GATE_PASS"
