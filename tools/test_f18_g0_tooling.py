import json
import pathlib
import tempfile
import unittest

from tools.f18_g0_capture_baseline import capture_baseline


EXPECTED_VERSION = "ELECTROSIM2-F17-R12-QUALIFIED"
EXPECTED_FLUTTER = "3.38.10"
EXPECTED_DART = "3.10.9"
EXPECTED_LEGACY_SHA = "569e05908592e6dd615bd80b342f6c7a28249850951d353dac988c5d2e1187bd"


def _write_fixture(root: pathlib.Path, *, version: str = EXPECTED_VERSION,
                   flutter: str = EXPECTED_FLUTTER, dart: str = EXPECTED_DART) -> None:
    (root / "VERSION").write_text(version + "\n", encoding="utf-8")
    (root / "ci").mkdir(parents=True)
    (root / "ci" / "TOOLCHAIN_LOCK.json").write_text(
        json.dumps({
            "schemaVersion": 1,
            "flutter": {
                "version": flutter,
                "channel": "stable",
                "dartVersion": dart,
                "frameworkRevision": "fixture",
            },
        }),
        encoding="utf-8",
    )
    (root / "reference").mkdir(parents=True)
    (root / "reference" / "REFERENCE_BASELINE.json").write_text(
        json.dumps({
            "phase": "F0",
            "status": "REFERENCE_FROZEN",
            "legacy_zip": {
                "filename": "ElectroSim-FIELDFIX01-R1.zip",
                "sha256": EXPECTED_LEGACY_SHA,
            },
        }),
        encoding="utf-8",
    )


class F18G0BaselineTests(unittest.TestCase):
    def test_capture_baseline_requires_f17_version(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            _write_fixture(root, version="WRONG")
            with self.assertRaisesRegex(ValueError, "VERSION"):
                capture_baseline(root)

    def test_capture_baseline_requires_locked_flutter_3_38_10_dart_3_10_9(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            _write_fixture(root, flutter="3.38.9")
            with self.assertRaisesRegex(ValueError, "Flutter"):
                capture_baseline(root)

        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            _write_fixture(root, dart="3.10.8")
            with self.assertRaisesRegex(ValueError, "Dart"):
                capture_baseline(root)

    def test_capture_baseline_records_legacy_sha_and_reference_paths(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            _write_fixture(root)
            snapshot = capture_baseline(root)
            self.assertEqual(snapshot["version"], EXPECTED_VERSION)
            self.assertEqual(snapshot["toolchain"]["flutter"], EXPECTED_FLUTTER)
            self.assertEqual(snapshot["toolchain"]["dart"], EXPECTED_DART)
            self.assertEqual(snapshot["legacy"]["sha256"], EXPECTED_LEGACY_SHA)
            self.assertEqual(
                snapshot["legacy"]["archivePath"],
                "reference/legacy/ElectroSim-FIELDFIX01-R1.zip",
            )
            self.assertEqual(
                snapshot["legacy"]["baselinePath"],
                "reference/REFERENCE_BASELINE.json",
            )

    def test_capture_baseline_is_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = pathlib.Path(td)
            _write_fixture(root)
            first = capture_baseline(root)
            second = capture_baseline(root)
            self.assertEqual(first, second)
            self.assertNotIn("timestamp", json.dumps(first).lower())


if __name__ == "__main__":
    unittest.main()
