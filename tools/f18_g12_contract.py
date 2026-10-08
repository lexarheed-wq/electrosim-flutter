#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
G11_MERGED_SHA = "3bb6d7368cf32351843afb8f35440dc65e129c35"
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
check("flutter-lock", lock.get("flutter", {}).get("version") == "3.38.10")
check("dart-lock", lock.get("flutter", {}).get("dartVersion") == "3.10.9")

for path in (
    "docs/f18/g7/F18_G7_REPORT.md",
    "docs/f18/g8/F18_G8_REPORT.md",
    "docs/f18/g9/F18_G9_REPORT.md",
    "docs/f18/g10/F18_G10_REPORT.md",
    "docs/f18/g11/F18_G11_REPORT.md",
    "docs/f18/g12/F18_G12_REPORT.md",
    ".github/workflows/f18-g11-tests-audits.yml",
    ".github/workflows/f18-g12-final-qualification.yml",
):
    check(f"required:{path}", (ROOT / path).is_file())

tracked = subprocess.check_output(
    ["git", "ls-files"], cwd=ROOT, text=True
).splitlines()
check(
    "no-one-shot-golden-workflow",
    not any("golden-refresh" in p or "golden-seed" in p for p in tracked),
)
check(
    "canvas-goldens-present",
    all(
        (ROOT / "packages/electrosim_canvas/test/goldens" / name).is_file()
        for name in (
            "canvas_compact.png",
            "canvas_medium.png",
            "canvas_expanded.png",
        )
    ),
)
check(
    "f9-current-goldens-present",
    all(
        (ROOT / "apps/electrosim/test/goldens" / name).is_file()
        for name in (
            "f9_compact_properties.png",
            "f9_medium_properties.png",
            "f9_expanded_properties.png",
            "f9_compact_student_diagnostic.png",
        )
    ),
)

# G12 must not change the product after the fully-qualified G11 integration SHA.
changed = subprocess.check_output(
    ["git", "diff", "--name-only", f"{G11_MERGED_SHA}..HEAD"],
    cwd=ROOT,
    text=True,
).splitlines()
allowed_prefixes = (
    ".github/workflows/f18-g12-final-qualification.yml",
    "tools/f18_g12_contract.py",
    "docs/f18/g12/",
)
unexpected = [
    path
    for path in changed
    if not any(
        path == prefix or (prefix.endswith("/") and path.startswith(prefix))
        for prefix in allowed_prefixes
    )
]
check("g12-no-product-code-drift-after-g11", not unexpected)

workflow = read(".github/workflows/f18-g12-final-qualification.yml")
check("g12-read-only-repository", "contents: read" in workflow)
check("g12-no-self-push", "git push" not in workflow)
check("g12-macos-intel-runner", "macos-15-intel" in workflow)
check("g12-release-build", "flutter build macos --release" in workflow)
check("g12-x86-64-proof", "x86_64" in workflow)
check("g12-sha256-proof", "shasum -a 256" in workflow)
check("g12-physical-marker-pending", "F18_PHYSICAL_MAC_PASS=PENDING_USER_VALIDATION" in workflow)

payload = {
    "phase": "F18-G12",
    "status": "PASS" if not errors else "FAIL",
    "g11MergedSha": G11_MERGED_SHA,
    "changedSinceG11": changed,
    "unexpectedProductChanges": unexpected,
    "checks": checks,
    "errors": errors,
}
print(json.dumps(payload, indent=2, ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
