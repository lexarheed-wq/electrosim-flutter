#!/usr/bin/env python3
"""Reconstruct the original premium 3D Dart painter, losslessly except comments
and indentation, and verify its SHA-256 before use in Flutter builds.

The base64 gzip source is a staging transport; the generated .dart file is the
real Flutter source, not an image or a simplified replacement widget.
"""
import base64
import gzip
import hashlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "tools/premium_rcd2p/disjoncteur_3d.dart.gz.b64"
TARGET = ROOT / "apps/electrosim/lib/reference_components/disjoncteur_3d.dart"
EXPECTED_SHA256 = "c5efdc302cdaa7c4f2cfa84671d64ead3546b480e9027cc3aa561b2ec9e5764a"

def main() -> None:
    payload = base64.b64decode(PACKAGE.read_text(encoding="ascii").strip(), validate=True)
    source = gzip.decompress(payload)
    actual = hashlib.sha256(source).hexdigest()
    if actual != EXPECTED_SHA256:
        raise SystemExit(f"PREMIUM_SOURCE_MISMATCH expected={EXPECTED_SHA256} actual={actual}")
    text = source.decode("utf-8")
    # The ZIP uses Dart-invalid decimal shorthand (-32., 10., etc.).
    # Correct syntax ONLY; these retain exactly the same numeric geometry.
    old = "[-32., -20., -5., 10., 25., 36.]"
    new = "[-32.0, -20.0, -5.0, 10.0, 25.0, 36.0]"
    if text.count(old) != 1:
        raise SystemExit("PREMIUM_GEOMETRY_LITERAL_MISMATCH")
    text = text.replace(old, new)
    for marker in (
        "class Disjoncteur3D extends StatefulWidget",
        "enum VueDisjoncteur",
        "class _Projection",
        "class _Scene",
        "class _DisjoncteurPainter",
        "Map<BorneDisjoncteur, Offset> positionsBornes",
    ):
        if marker not in text:
            raise SystemExit(f"PREMIUM_SOURCE_INCOMPLETE: {marker}")
    for prohibited in ("scene.text('Schneider'", "scene.text('Acti9'", "scene.text('iDD40K'"):
        if prohibited in text:
            raise SystemExit(f"PREMIUM_COMMERCIAL_MARKING_FOUND: {prohibited}")
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(text, encoding='utf-8')
    print(f"PREMIUM_DART_SOURCE_PASS path={TARGET.relative_to(ROOT)} bytes={len(source)} sha256={actual}")

if __name__ == "__main__":
    main()
