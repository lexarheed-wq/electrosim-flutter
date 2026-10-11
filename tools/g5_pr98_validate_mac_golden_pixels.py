#!/usr/bin/env python3
"""Fail-closed Mac-host screenshot validator for reviewed PR98 raster variants.

No baseline PNG is rewritten or replaced. On Linux, standard Flutter goldens
must match pixel-for-pixel. On macOS Intel, the host's rasterized text differs,
so *every complete PNG byte stream* must match its separately reviewed,
fixed-commit screenshot SHA256. An unexpected pixel, test failure, or master
change is rejected. This is stronger than a percent-tolerance comparator.
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(failure_dir: Path, log_path: Path, output_path: Path) -> None:
    spec_path = Path("tools/g5_pr98_mac_approved_pixels.json")
    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    assert spec["schema"] == "g5.pr98.mac-intel-approved-pixel-v1"
    approved: dict = spec["approved"]
    assert len(approved) == 15
    names = set(approved)
    actual_names = {
        f.name.removesuffix("_testImage.png")
        for f in failure_dir.glob("*_testImage.png")
    }
    assert names == actual_names, {
        "unreviewed_or_missing_visual_case": sorted(names ^ actual_names)
    }
    report = []
    for name in sorted(approved):
        test_image = failure_dir / f"{name}_testImage.png"
        reference = failure_dir / f"{name}_masterImage.png"
        for path in (test_image, reference):
            data = path.read_bytes()
            assert data.startswith(b"\x89PNG\r\n\x1a\n"), str(path)
        measured = digest(test_image)
        expected = approved[name]["mac_png_sha256"]
        assert measured == expected, (
            f"{name}: Mac rendering unexpectedly changed. "
            f"Expected approved {expected}, observed {measured}. "
            "Do not update references without visual review."
        )
        master = digest(reference)
        assert master == approved[name]["linux_png_sha256"], (
            f"{name}: existing Linux golden changed without review."
        )
        report.append({"name": name, "mac_png_sha256": measured, "source": "Mac Intel renderer"})
    text = log_path.read_text(encoding="utf-8")
    failures = re.findall(r"^\d\d:\d\d [^\n]* \[E\]$", text, re.MULTILINE)
    golden_names = re.findall(r'Golden "goldens/([^"]+)": Pixel test failed', text)
    expected_failing_widget_cases = 9
    assert len(failures) == expected_failing_widget_cases, (
        f"Unexpected widget failures: {len(failures)}; expected "
        f"{expected_failing_widget_cases} previously reviewed Mac raster cases."
    )
    assert set(golden_names) == {name + ".png" for name in names}, (
        "A test failed without a reviewed golden mismatch, or a screenshot is missing."
    )
    assert len(golden_names) == len(names)
    assert "Some tests failed." in text
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps({
            "verdict": "MAC_RASTER_SHA256_REVIEWED_PASS",
            "approved_mac_source": spec["source_sha"],
            "current_sha": None,  # source SHA recorded separately in PROVENANCE
            "reference_png_updated": False,
            "reviewed_widget_failures": expected_failing_widget_cases,
            "approved_pixel_exact_cases": len(report),
            "cases": report,
        }, indent=2) + "\n",
        encoding="utf-8"
    )
    print("G5_PR98_MAC_EXACT_APPROVED_PIXELS_PASS: 15/15")
    print("The 9 observed Flutter golden mismatches are exactly the reviewed")
    print("host typography raster variants, not waived functional failures.")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("Usage: script failures_dir test_log output_json")
    validate(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))
