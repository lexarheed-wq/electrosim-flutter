#!/usr/bin/env python3
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PRODUCT_BASE_SHA = "b9a3cc68e95635e8ab48a313bb8f57b694eb6955"
ALLOWED_AFTER_BASE = {
    ".github/workflows/postv2-p1-final-qualification.yml",
    "tools/postv2_p1_final_contract.py",
    "docs/postv2/p1/POSTV2_P1_FINAL_QUALIFICATION.md",
}

errors = []

def require(condition: bool, message: str) -> None:
    if not condition:
        errors.append(message)

lock = json.loads((ROOT / "ci/TOOLCHAIN_LOCK.json").read_text(encoding="utf-8"))
require(lock["flutter"]["version"] == "3.38.10", "Flutter lock must remain 3.38.10")
require(lock["flutter"]["dartVersion"] == "3.10.9", "Dart lock must remain 3.10.9")

required = (
    "tools/postv2_p1_contract.py",
    "docs/postv2/p1/POSTV2_P1_REPORT.md",
    ".github/workflows/postv2-p1-engine-hardening.yml",
    "packages/electrosim_solver_dc/test/postv2_p1_source_associations_test.dart",
    "packages/electrosim_solver_dc/test/postv2_p1_receiver_polarity_test.dart",
    "packages/electrosim_solver_dc/test/postv2_p1_invariants_test.dart",
    "packages/electrosim_pv/test/postv2_p1_polarity_test.dart",
    "packages/electrosim_diagnostics/test/postv2_p1_eie_authority_test.dart",
    "apps/electrosim/test/postv2_p1_wiring_policy_test.dart",
    "apps/electrosim/test/postv2_p1_motor_visual_direction_test.dart",
)
for rel in required:
    require((ROOT / rel).is_file(), f"Missing P1 qualification input: {rel}")

changed = subprocess.check_output(
    ["git", "diff", "--name-only", f"{PRODUCT_BASE_SHA}..HEAD"],
    cwd=ROOT,
    text=True,
).splitlines()
unexpected = sorted(set(changed) - ALLOWED_AFTER_BASE)
require(
    not unexpected,
    "Product drift after qualified P1 integration SHA: " + ", ".join(unexpected),
)

workflow = (ROOT / ".github/workflows/postv2-p1-final-qualification.yml").read_text(
    encoding="utf-8"
)
for marker in (
    "macos-15-intel",
    "flutter build macos --release",
    "grep -qi 'x86_64'",
    "POSTV2_P1_AUTOMATED_FINAL_PASS",
    "POSTV2_P1_PHYSICAL_MAC_PASS=PENDING_USER_VALIDATION",
):
    require(marker in workflow, f"Missing final qualification workflow marker: {marker}")

result = {
    "status": "PASS" if not errors else "FAIL",
    "productBaseSha": PRODUCT_BASE_SHA,
    "changedSinceProductBase": changed,
    "errors": errors,
}
print(json.dumps(result, indent=2, ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
