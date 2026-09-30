#!/usr/bin/env python3
import argparse
import json
import pathlib
import sys
from typing import Any

EXPECTED_VERSION = "ELECTROSIM2-F17-R12-QUALIFIED"
EXPECTED_FLUTTER = "3.38.10"
EXPECTED_DART = "3.10.9"
QUALIFIED_MAIN_SHA = "554d156839418f2be690980fe8acb941f776a425"

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT_JSON = ROOT / "docs" / "f18" / "g0" / "F18_G0_BASELINE.json"
OUT_MD = ROOT / "docs" / "f18" / "g0" / "F18_G0_BASELINE.md"


def _read_json(path: pathlib.Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def capture_baseline(root: pathlib.Path) -> dict[str, object]:
    version = (root / "VERSION").read_text(encoding="utf-8").strip()
    if version != EXPECTED_VERSION:
        raise ValueError(
            f"VERSION must be {EXPECTED_VERSION!r}, got {version!r}"
        )

    lock = _read_json(root / "ci" / "TOOLCHAIN_LOCK.json")
    flutter = lock.get("flutter") or {}
    flutter_version = flutter.get("version")
    dart_version = flutter.get("dartVersion")
    if flutter_version != EXPECTED_FLUTTER:
        raise ValueError(
            f"Flutter must be {EXPECTED_FLUTTER}, got {flutter_version!r}"
        )
    if dart_version != EXPECTED_DART:
        raise ValueError(
            f"Dart must be {EXPECTED_DART}, got {dart_version!r}"
        )

    reference = _read_json(root / "reference" / "REFERENCE_BASELINE.json")
    legacy = reference.get("legacy_zip") or {}
    filename = legacy.get("filename")
    sha256 = legacy.get("sha256")
    if not filename or not sha256:
        raise ValueError("REFERENCE_BASELINE.json lacks legacy_zip identity")

    return {
        "schemaVersion": 1,
        "phase": "F18-G0",
        "qualifiedMainSha": QUALIFIED_MAIN_SHA,
        "version": version,
        "toolchain": {
            "flutter": flutter_version,
            "dart": dart_version,
            "channel": flutter.get("channel"),
            "frameworkRevision": flutter.get("frameworkRevision"),
        },
        "legacy": {
            "filename": filename,
            "sha256": sha256,
            "archivePath": f"reference/legacy/{filename}",
            "baselinePath": "reference/REFERENCE_BASELINE.json",
        },
    }


def _json_text(snapshot: dict[str, object]) -> str:
    return json.dumps(snapshot, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def _markdown_text(snapshot: dict[str, object]) -> str:
    toolchain = snapshot["toolchain"]
    legacy = snapshot["legacy"]
    assert isinstance(toolchain, dict)
    assert isinstance(legacy, dict)
    return (
        "# F18-G0 — Baseline F17 qualifiée\n\n"
        "Cette baseline est déterministe et ne contient aucun horodatage.\n\n"
        f"- Base main qualifiée : `{snapshot['qualifiedMainSha']}`\n"
        f"- VERSION : `{snapshot['version']}`\n"
        f"- Flutter : `{toolchain['flutter']}`\n"
        f"- Dart : `{toolchain['dart']}`\n"
        f"- Référence V1 : `{legacy['archivePath']}`\n"
        f"- SHA-256 V1 : `{legacy['sha256']}`\n\n"
        "Le code produit F17 reste inchangé pendant G0.\n"
    )


def _write(snapshot: dict[str, object]) -> None:
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.write_text(_json_text(snapshot), encoding="utf-8")
    OUT_MD.write_text(_markdown_text(snapshot), encoding="utf-8")


def _check(snapshot: dict[str, object]) -> None:
    expected = {
        OUT_JSON: _json_text(snapshot),
        OUT_MD: _markdown_text(snapshot),
    }
    errors: list[str] = []
    for path, content in expected.items():
        if not path.exists():
            errors.append(f"missing:{path.relative_to(ROOT)}")
        elif path.read_text(encoding="utf-8") != content:
            errors.append(f"drift:{path.relative_to(ROOT)}")
    if errors:
        raise ValueError("; ".join(errors))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)

    try:
        snapshot = capture_baseline(ROOT)
        if args.check:
            _check(snapshot)
        else:
            _write(snapshot)
    except Exception as exc:
        print(f"F18_G0_BASELINE_FAIL {exc}", file=sys.stderr)
        return 1

    print("F18_G0_BASELINE_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
