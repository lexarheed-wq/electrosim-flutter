#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []
checks: dict[str, bool] = {}


def check(name: str, ok: bool) -> None:
    checks[name] = bool(ok)
    if not ok:
        errors.append(name)


def read(path: str) -> str:
    file = ROOT / path
    if not file.is_file():
        errors.append(f"missing:{path}")
        return ""
    return file.read_text(encoding="utf-8")


lock = json.loads(read("ci/TOOLCHAIN_LOCK.json"))
flutter = str(lock.get("flutter", {}).get("version", ""))
dart = str(lock.get("flutter", {}).get("dartVersion", ""))
check("toolchain-flutter-3.38.10", flutter == "3.38.10")
check("toolchain-dart-3.10.9", dart == "3.10.9")

required_workflows = [
    ".github/workflows/f18-g1-design-system.yml",
    ".github/workflows/f18-g2-shell-navigation.yml",
    ".github/workflows/f18-g3-session-dashboard.yml",
    ".github/workflows/f18-g4-visual-framework.yml",
    ".github/workflows/f18-g5-supported-parity.yml",
    ".github/workflows/f18-g6-canvas-wiring.yml",
    ".github/workflows/f18-g7-instruments-properties.yml",
    ".github/workflows/f18-g8-tp-teacher-student.yml",
    ".github/workflows/f18-g9-eie-internal.yml",
    ".github/workflows/f18-g10-v2-pure-libraries.yml",
]
for path in required_workflows:
    check(f"workflow:{Path(path).stem}", (ROOT / path).is_file())

required_docs = [f"docs/f18/g{i}" for i in range(0, 11)]
for path in required_docs:
    check(f"documentation:{path}", (ROOT / path).is_dir())

required_tests = [
    "apps/electrosim/test/f18_g2_navigation_test.dart",
    "apps/electrosim/test/f18_g3_session_dashboard_test.dart",
    "apps/electrosim/test/f18_g4_visual_framework_gate_test.dart",
    "apps/electrosim/test/f18_g5_supported_parity_gate_test.dart",
    "apps/electrosim/test/f18_g6_multiselect_test.dart",
    "apps/electrosim/test/f18_g7_instruments_properties_test.dart",
    "apps/electrosim/test/f18_g8_tp_teacher_student_test.dart",
    "apps/electrosim/test/f18_g9_internal_eie_test.dart",
    "packages/electrosim_scenarios/test/f18_g10_v2_product_libraries_test.dart",
    "packages/electrosim_canvas/test/canvas_performance_test.dart",
]
for path in required_tests:
    check(f"test:{Path(path).name}", (ROOT / path).is_file())

all_tests = list((ROOT / "apps/electrosim/test").glob("*.dart"))
for package_test_dir in (ROOT / "packages").glob("*/test"):
    all_tests.extend(package_test_dir.glob("*.dart"))
check("test-inventory-at-least-100", len(all_tests) >= 100)

panels = read("apps/electrosim/lib/f9_context_panels.dart")
main = read("apps/electrosim/lib/main.dart")
g10_catalog = read("packages/electrosim_scenarios/lib/src/v2_product_catalog.dart")
g10_faults = read("packages/electrosim_scenarios/lib/src/v2_product_faults.dart")

check(
    "eie-teacher-only",
    "bool get showEie => role == F9UserRole.teacher;" in panels,
)
check("student-coach-not-reintroduced", "coach" not in panels.lower())
check("single-delete-policy-no-properties-delete", "properties-delete-element" not in panels)
check("single-delete-policy-topbar-delete", "onDeleteSelected:" in main)
check("g10-does-not-import-bootstrap-catalog", "f16_catalog" not in g10_catalog.lower())
check("g10-faults-do-not-import-healthy-library", "v2_product_examples" not in g10_faults)
check(
    "g10-faults-no-example-linkage",
    not any(x in g10_faults.lower() for x in ("exampleid", "example_id", "examplecircuit")),
)

# Temporary payload/bootstrap files were useful during construction but must never
# survive in the integration candidate.
tracked = subprocess.check_output(
    ["git", "ls-files"], cwd=ROOT, text=True
).splitlines()
payload_files = [
    path for path in tracked
    if re.search(r"(^|/)\.f18_g\d+_payload(/|$)", path)
]
check("no-temporary-f18-payloads", not payload_files)

# Final F18 workflows G7-G10 are read-only validators: CI must not normalize or
# mutate the integration branch while declaring a gate.
for path in required_workflows[6:]:
    workflow = read(path)
    check(f"readonly:{Path(path).stem}", "contents: read" in workflow)
    check(
        f"no-self-push:{Path(path).stem}",
        "git push" not in workflow and "contents: write" not in workflow,
    )

payload = {
    "phase": "F18-G11",
    "status": "PASS" if not errors else "FAIL",
    "testFileCount": len(all_tests),
    "checks": checks,
    "temporaryPayloadFiles": payload_files,
    "errors": errors,
}
print(json.dumps(payload, indent=2, ensure_ascii=False))

if len(sys.argv) == 2:
    output = ROOT / sys.argv[1]
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

raise SystemExit(0 if not errors else 1)
