#!/usr/bin/env python3
"""Fail release packaging when the advertised student QR leads to missing Web assets.

Usage: python3 tools/f17_validate_student_mac_bundle.py path/to/App.app
   or: python3 tools/f17_validate_student_mac_bundle.py path/to/app.zip
"""
from __future__ import annotations

import sys
from pathlib import Path
from zipfile import ZipFile, BadZipFile

REQUIRED = ("index.html", "main.dart.js")
WEB_FOLDER = "Contents/Resources/electrosim_student_web/"


def validate_app(path: Path) -> None:
    if path.suffix != ".app" or not path.is_dir():
        raise ValueError(f"Expected an unpacked .app folder: {path}")
    folder = path / WEB_FOLDER
    for filename in REQUIRED:
        asset = folder / filename
        if not asset.is_file() or asset.stat().st_size == 0:
            raise ValueError(f"F17_WEB_BUNDLE_MISSING: {asset}")


def validate_zip(path: Path) -> None:
    if not path.is_file() or path.suffix != ".zip":
        raise ValueError(f"Expected a .zip archive: {path}")
    with ZipFile(path) as archive:
        names = archive.namelist()
        for filename in REQUIRED:
            suffix = "/" + WEB_FOLDER + filename
            files = [n for n in names if n.endswith(suffix)]
            if len(files) != 1:
                raise ValueError(f"F17_WEB_BUNDLE_MISSING: {filename} in {path}")
            if archive.getinfo(files[0]).file_size == 0:
                raise ValueError(f"F17_WEB_BUNDLE_EMPTY: {filename} in {path}")
        bad = archive.testzip()
        if bad:
            raise ValueError(f"F17_MAC_ZIP_CORRUPT: {bad}")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__, file=sys.stderr)
        return 64
    path = Path(argv[1])
    try:
        if path.suffix == ".app":
            validate_app(path)
        else:
            validate_zip(path)
    except (OSError, ValueError, BadZipFile) as error:
        print(f"F17_MAC_STUDENT_WEB_FAIL: {error}", file=sys.stderr)
        return 2
    print(f"F17_MAC_STUDENT_WEB_PASS: {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
