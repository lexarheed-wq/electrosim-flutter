import csv
import json
import pathlib
import tempfile
import unittest

from tools.f18_g0_capture_baseline import capture_baseline, find_forbidden_g0_changes
from tools.f18_g0_build_parity import check_committed_parity, extract_catalog_counts, extract_palette_definitions, validate_capability_parity, validate_parity


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


class F18G0ParityTests(unittest.TestCase):
    def test_extract_palette_definitions_finds_exact_current_catalog(self) -> None:
        source = (pathlib.Path("apps/electrosim/lib/f9_component_palette.dart")
                  .read_text(encoding="utf-8"))
        items = extract_palette_definitions(source)
        self.assertEqual(len(items), 13)
        self.assertEqual(len({item["keyName"] for item in items}), 13)
        self.assertEqual(len({item["modelType"] for item in items}), 13)
        self.assertEqual(items[0]["keyName"], "source-dc-24v")
        self.assertEqual(items[0]["modelType"], "dc_voltage_source")
        models = {item["modelType"] for item in items}
        self.assertIn("relay_coil", models)
        self.assertIn("push_button_nc", models)

    def test_extract_palette_definitions_rejects_duplicate_keys(self) -> None:
        block = """
const List<F9PaletteDefinition> f9PaletteCatalog = <F9PaletteDefinition>[
  F9PaletteDefinition(
    keyName: 'dup',
    title: 'A',
    category: 'X',
    modelType: 'a',
    icon: Icons.add,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
  ),
  F9PaletteDefinition(
    keyName: 'dup',
    title: 'B',
    category: 'X',
    modelType: 'b',
    icon: Icons.add,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
  ),
];
"""
        with self.assertRaisesRegex(ValueError, "duplicate palette key"):
            extract_palette_definitions(block)

    def test_extract_catalog_counts_finds_five_examples_and_three_faults(self) -> None:
        sources = []
        for path in (
            "packages/electrosim_scenarios/lib/src/f10_examples.dart",
            "packages/electrosim_scenarios/lib/src/f11_fault_scenarios.dart",
            "packages/electrosim_scenarios/lib/src/f16_catalog.dart",
        ):
            sources.append(pathlib.Path(path).read_text(encoding="utf-8"))
        counts = extract_catalog_counts("\n".join(sources))
        self.assertEqual(counts, {"examples": 5, "faultScenarios": 3})


class F18G0ParityMatrixTests(unittest.TestCase):
    def test_committed_product_parity_matrix_is_exhaustive(self) -> None:
        path = pathlib.Path("docs/f18/g0/F18_PRODUCT_PARITY.csv")
        with path.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual(validate_parity(rows), [])
        self.assertEqual(len(rows), 217)
        self.assertEqual(sum(r["entity_class"] == "palette-component" for r in rows), 195)
        self.assertEqual(sum(r["entity_class"] == "socket" for r in rows), 4)
        self.assertEqual(sum(r["entity_class"] == "external-appliance" for r in rows), 18)
        self.assertNotIn("UNREVIEWED", {r["disposition"] for r in rows})

    def test_validate_parity_rejects_duplicate_legacy_ids(self) -> None:
        row = {
            "legacy_id": "dup", "label": "Dup", "entity_class": "palette-component",
            "legacy_category": "X", "legacy_modes": "CC", "flutter_model_type": "",
            "disposition": "DEFER", "reason": "Needs a model", "target_gate": "G5",
            "visual_family": "x",
        }
        errors = validate_parity([row, dict(row)])
        self.assertTrue(any("duplicate legacy_id" in error for error in errors))

    def test_validate_parity_rejects_invalid_disposition_and_empty_reason(self) -> None:
        row = {
            "legacy_id": "x", "label": "X", "entity_class": "palette-component",
            "legacy_category": "X", "legacy_modes": "CC", "flutter_model_type": "",
            "disposition": "UNREVIEWED", "reason": "", "target_gate": "",
            "visual_family": "",
        }
        errors = validate_parity([row])
        self.assertTrue(any("invalid disposition" in error for error in errors))
        self.assertTrue(any("reason" in error for error in errors))
        self.assertTrue(any("target_gate" in error for error in errors))
        self.assertTrue(any("visual_family" in error for error in errors))

    def test_validate_parity_rejects_unknown_flutter_model_type_outside_rebuild(self) -> None:
        row = {
            "legacy_id": "x", "label": "X", "entity_class": "palette-component",
            "legacy_category": "X", "legacy_modes": "CC",
            "flutter_model_type": "invented_model",
            "disposition": "DEFER", "reason": "Deferred", "target_gate": "G5",
            "visual_family": "x",
        }
        errors = validate_parity([row])
        self.assertTrue(any("unknown flutter_model_type" in error for error in errors))


class F18G0CapabilityParityTests(unittest.TestCase):
    REQUIRED_CAPABILITIES = {
        "Accueil",
        "Session",
        "Centre de maintenance",
        "Centre de conception",
        "Palette composants",
        "Canvas",
        "Câblage interactif",
        "Mesures",
        "Énergie",
        "EIE / diagnostic",
        "Sauvegardes locales",
        "TP câblage",
        "Recherche de dérangement",
        "Supervision professeur",
        "Responsive/mobile",
        "LAN professeur/élève",
    }

    def test_committed_capability_matrix_covers_required_product_surface(self) -> None:
        path = pathlib.Path("docs/f18/g0/F18_CAPABILITY_PARITY.csv")
        with path.open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
        self.assertEqual(validate_capability_parity(rows), [])
        capabilities = {row["capability"] for row in rows}
        self.assertTrue(self.REQUIRED_CAPABILITIES.issubset(capabilities))
        self.assertGreaterEqual(len(rows), 22)

    def test_validate_capability_parity_rejects_missing_evidence_and_acceptance(self) -> None:
        row = {
            "capability": "X",
            "legacy_evidence": "",
            "flutter_evidence": "",
            "current_state": "PARTIAL",
            "target_gate": "",
            "acceptance": "",
        }
        errors = validate_capability_parity([row])
        self.assertTrue(any("legacy_evidence" in error for error in errors))
        self.assertTrue(any("flutter_evidence" in error for error in errors))
        self.assertTrue(any("target_gate" in error for error in errors))
        self.assertTrue(any("acceptance" in error for error in errors))

    def test_validate_capability_parity_rejects_unknown_state_and_duplicates(self) -> None:
        row = {
            "capability": "X",
            "legacy_evidence": "legacy",
            "flutter_evidence": "flutter",
            "current_state": "UNKNOWN",
            "target_gate": "G2",
            "acceptance": "works",
        }
        errors = validate_capability_parity([row, dict(row)])
        self.assertTrue(any("invalid current_state" in error for error in errors))
        self.assertTrue(any("duplicate capability" in error for error in errors))


class F18G0DriftGuardTests(unittest.TestCase):
    def test_drift_guard_allows_only_g0_docs_tools_tests_and_workflow(self) -> None:
        allowed = [
            "docs/f18/g0/F18_G0_REPORT.md",
            "docs/superpowers/specs/2026-09-30-electrosim-f18-product-parity-design.md",
            "docs/superpowers/plans/2026-09-30-electrosim-f18-g0-baseline-inventory.md",
            "tools/f18_g0_capture_baseline.py",
            "tools/f18_g0_build_parity.py",
            "tools/test_f18_g0_tooling.py",
            ".github/workflows/f18-g0-baseline-inventory.yml",
        ]
        self.assertEqual(find_forbidden_g0_changes(allowed), [])

    def test_drift_guard_rejects_runtime_and_core_library_changes(self) -> None:
        paths = [
            "apps/electrosim/lib/main.dart",
            "packages/electrosim_domain/lib/src/circuit_state.dart",
            "packages/electrosim_solver_dc/lib/src/solver.dart",
        ]
        self.assertEqual(find_forbidden_g0_changes(paths), paths)

    def test_drift_guard_rejects_version_and_toolchain_changes(self) -> None:
        paths = ["VERSION", "ci/TOOLCHAIN_LOCK.json"]
        self.assertEqual(find_forbidden_g0_changes(paths), paths)


class F18G0CommittedChecksTests(unittest.TestCase):
    def test_committed_parity_check_accepts_current_g0_artifacts(self) -> None:
        errors = check_committed_parity(pathlib.Path("."))
        self.assertEqual(errors, [])


if __name__ == "__main__":
    unittest.main()
