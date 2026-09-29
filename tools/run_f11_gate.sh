#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FLUTTER_SUPPRESS_ANALYTICS=true
run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; }

run_step "f11-f10-freeze" python3 "$ROOT/tools/f11_f10_freeze_check.py"
run_step "f11-static-contract" python3 "$ROOT/tools/f11_static_contract_check.py"
run_step "f11-security-static" python3 "$ROOT/tools/f11_security_static_check.py"
run_step "f9-architecture-regression" python3 "$ROOT/tools/f9_architecture_guard.py"
run_step "f9-static-regression" python3 "$ROOT/tools/f9_static_contract_check.py"
run_step "f9-accessibility-regression" python3 "$ROOT/tools/f9_accessibility_audit.py"
run_step "f9-ux-canvas-regression" python3 "$ROOT/tools/f9_ux_canvas_static_check.py"
run_step "f9-status-bar-regression" python3 "$ROOT/tools/f9_status_bar_static_check.py"
run_step "test-vectors" python3 "$ROOT/tools/validate_test_vectors.py"
run_step "f10-prepare-f9-goldens" "$ROOT/tools/f10_prepare_f9_goldens.sh"

cd "$ROOT/packages/electrosim_ui_kit"
run_step "F9-ui-kit-analyze" flutter analyze
run_step "F9-ui-kit-test" flutter test

cd "$ROOT/packages/electrosim_canvas"
run_step "F8-canvas-regression-analyze" flutter analyze
run_step "F8-canvas-regression-test" flutter test test/viewport_controller_test.dart test/hit_test_engine_test.dart test/simulator_canvas_test.dart

cd "$ROOT/apps/electrosim"
run_step "F9-app-analyze" flutter analyze
run_step "F9-app-functional-tests" flutter test test/f0_smoke_test.dart test/f9_auto_placement_test.dart test/f9_element_editor_test.dart test/f9_wiring_policy_test.dart test/f9_canvas_interaction_test.dart test/f9_shell_test.dart
run_step "F9-golden-regression" flutter test test/f9_goldens_test.dart

for PKG in electrosim_domain electrosim_topology electrosim_solver_dc electrosim_solver_ac electrosim_measurements electrosim_pv electrosim_energy; do
  cd "$ROOT/packages/$PKG"
  run_step "regression-$PKG-pub-get" dart pub get
  run_step "regression-$PKG-analyze" dart analyze
  run_step "regression-$PKG-test" dart test
done

cd "$ROOT/packages/electrosim_scenarios"
run_step "F10-F11-scenarios-pub-get" dart pub get
run_step "F10-F11-scenarios-analyze" dart analyze
run_step "F10-F11-scenarios-test" dart test
run_step "F10-example-validator" dart run tool/validate_examples.dart
run_step "F11-fault-validator" dart run tool/validate_fault_scenarios.dart

mkdir -p "$ROOT/docs/f11"
cd "$ROOT/packages/electrosim_scenarios"
dart run tool/validate_fault_scenarios.dart > "$ROOT/docs/f11/audit_catalog.json"
python3 "$ROOT/tools/f11_security_static_check.py" > "$ROOT/docs/f11/audit_security.json"
cd "$ROOT"
run_step "f11-refresh-manifest" python3 "$ROOT/tools/generate_f11_manifest.py"
run_step "f11-verify-manifest" python3 "$ROOT/tools/verify_f11_manifest.py"
echo "F11_GATE_PASS"
