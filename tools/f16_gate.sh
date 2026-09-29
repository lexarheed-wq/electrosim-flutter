#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="$ROOT/packages/electrosim_scenarios"
AUDIT="$ROOT/docs/f16/audit_catalog.json"

cd "$PKG"
dart pub get
dart analyze
dart test test/example_repository_test.dart
dart test test/fault_scenario_repository_test.dart
dart test test/f16_catalog_test.dart
dart run tool/f16_catalog_audit.dart "$AUDIT"

python3 - "$AUDIT" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
data = json.loads(p.read_text())
assert data["phase"] == "F16-R1"
assert data["status"] == "PASS"
assert data["examples"]["count"] == data["examples"]["signed"]
assert data["faultScenarios"]["count"] == data["faultScenarios"]["signed"]
assert data["legacyImported"] is False
assert data["exampleFaultCoupling"] is False
print("F16_AUDIT_CATALOG_PASS")
PY

printf 'F16_GATE_PASS\n'
