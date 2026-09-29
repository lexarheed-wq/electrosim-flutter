#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FLUTTER_SUPPRESS_ANALYTICS=true
run_step(){ local name="$1"; shift; echo "=== $name ==="; "$@"; }
run_step "f13-f12-freeze" python3 "$ROOT/tools/f13_f12_freeze_check.py"
run_step "f13-static-contract" python3 "$ROOT/tools/f13_static_contract_check.py"
run_step "f13-security" python3 "$ROOT/tools/f13_security_static_check.py"
run_step "f12-static-regression" python3 "$ROOT/tools/f12_static_contract_check.py"
run_step "f12-gate-regression" python3 "$ROOT/tools/f12_gate_contract_check.py"
run_step "f11-static-regression" python3 "$ROOT/tools/f11_static_contract_check.py"
run_step "f11-security-regression" python3 "$ROOT/tools/f11_security_static_check.py"
run_step "f9-architecture-regression" python3 "$ROOT/tools/f9_architecture_guard.py"
run_step "f9-accessibility-regression" python3 "$ROOT/tools/f9_accessibility_audit.py"
run_step "f9-ux-canvas-regression" python3 "$ROOT/tools/f9_ux_canvas_static_check.py"
run_step "test-vectors" python3 "$ROOT/tools/validate_test_vectors.py"
run_step "f10-prepare-f9-goldens" "$ROOT/tools/f10_prepare_f9_goldens.sh"

cd "$ROOT/packages/electrosim_diagnostics"
run_step "F13-diagnostics-pub-get" dart pub get
run_step "F13-diagnostics-analyze" dart analyze
run_step "F13-diagnostics-test" dart test
run_step "F13-eie-validator" dart run tool/validate_eie.dart

cd "$ROOT/packages/electrosim_tp"
run_step "F12-tp-pub-get" dart pub get
run_step "F12-tp-analyze" dart analyze
run_step "F12-tp-test" dart test
run_step "F12-tp-validator" dart run tool/validate_tp.dart

cd "$ROOT/packages/electrosim_scenarios"
run_step "F10-F11-scenarios-pub-get" dart pub get
run_step "F10-F11-scenarios-analyze" dart analyze
run_step "F10-F11-scenarios-test" dart test
run_step "F11-fault-validator" dart run tool/validate_fault_scenarios.dart

cd "$ROOT/apps/electrosim"
run_step "F9-app-analyze" flutter analyze
run_step "F9-app-functional-tests" flutter test test/f0_smoke_test.dart test/f9_auto_placement_test.dart test/f9_element_editor_test.dart test/f9_wiring_policy_test.dart test/f9_canvas_interaction_test.dart test/f9_shell_test.dart
run_step "F9-golden-regression" flutter test test/f9_goldens_test.dart

mkdir -p "$ROOT/docs/f13"
cd "$ROOT/packages/electrosim_diagnostics"
dart run tool/validate_eie.dart > "$ROOT/docs/f13/audit_eie.json"
cd "$ROOT"
run_step "f13-refresh-manifest" python3 "$ROOT/tools/generate_f13_manifest.py"
run_step "f13-verify-manifest" python3 "$ROOT/tools/verify_f13_manifest.py"
echo "F13_GATE_PASS"
