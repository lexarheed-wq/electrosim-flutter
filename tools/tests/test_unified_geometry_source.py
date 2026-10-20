import copy
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "g5_3d_remaining"))

from unified_geometry_contract import (  # noqa: E402
    load_crusher_geometry,
    load_lot_contract,
    load_manifest,
    native_catalogue_specs,
)


MANIFEST_PATH = ROOT / "apps/electrosim/assets/g5_industrial/geometry.unified.json"
CONTRACT_ROOT = ROOT / "tools/g5_3d_remaining"


class UnifiedGeometrySourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = load_manifest(MANIFEST_PATH)

    def test_all_26_native_models_are_generated_from_manifest(self):
        specs = native_catalogue_specs(self.manifest)
        components = self.manifest["components"]
        expected = {
            key
            for key, component in components.items()
            if "board_size" in component
        }
        self.assertEqual(len(expected), 26)
        self.assertEqual(set(specs), expected)
        for key, spec in specs.items():
            component = components[key]
            for field in (
                "type",
                "variant",
                "size",
                "board_size",
                "ports",
                "service_box",
                "three_phase",
            ):
                self.assertEqual(spec[field], component[field], f"{key}.{field}")

    def test_blender_jobs_merge_only_render_metadata_with_manifest_geometry(self):
        all_jobs = {}
        for lot in ("06_15", "16_26", "sockets"):
            source_path = CONTRACT_ROOT / f"lot_{lot}_contract.json"
            source = json.loads(source_path.read_text())
            jobs = load_lot_contract(lot, manifest=self.manifest)
            self.assertEqual(set(jobs), set(source))
            for key, sidecar in source.items():
                self.assertLessEqual(
                    set(sidecar), {"kind", "terminal_z", "terminal_scale"}, key
                )
                component = self.manifest["components"][key]
                job = jobs[key]
                self.assertEqual(job["visual"], component["type"], key)
                self.assertEqual(job["variant"], component["variant"], key)
                self.assertEqual(job["size"], component["size"], key)
                self.assertEqual(job["board"], component["board_size"], key)
                self.assertEqual(job["ports"], component["ports"], key)
                self.assertEqual(job["kind"], sidecar["kind"], key)
                x, y, width, height = component["service_box"]
                self.assertEqual(
                    job["box"],
                    [
                        x + width / 2,
                        y + height / 2,
                        width,
                        height,
                        sidecar["terminal_z"],
                    ],
                    key,
                )
                if "terminal_scale" in sidecar:
                    self.assertEqual(job["terminal_scale"], sidecar["terminal_scale"])
                all_jobs[key] = job
        self.assertEqual(len(all_jobs), 26)

    def test_specialized_crusher_geometry_comes_from_manifest(self):
        geometry = load_crusher_geometry(self.manifest)
        component = self.manifest["components"]["external-crusher"]
        self.assertEqual(geometry["size"], component["size"])
        self.assertEqual(geometry["ports"], component["ports"])
        self.assertEqual(geometry["ports_7t_extra"], component["ports_7t_extra"])
        self.assertNotIn("board_size", geometry)
        self.assertNotIn("service_box", geometry)

    def test_manifest_covers_exactly_27_complete_models_with_front_and_palette_assets(self):
        native_keys = set(native_catalogue_specs(self.manifest))
        model_keys = native_keys | {"external-crusher"}
        components = self.manifest["components"]
        self.assertEqual(len(model_keys), 27)
        self.assertEqual(components["external-crusher"]["status"], "complete")
        for key in model_keys:
            component = components[key]
            self.assertEqual(component["status"], "complete", key)
            assets = component["assets"]
            self.assertIn("front", assets, key)
            self.assertIn("palette", assets, key)
            for role in ("front", "palette"):
                relative = Path(assets[role])
                self.assertFalse(relative.is_absolute(), f"{key}.{role}")
                self.assertNotIn("..", relative.parts, f"{key}.{role}")
                self.assertTrue(
                    (ROOT / "apps/electrosim/assets" / relative).is_file(),
                    f"{key}.{role}: {relative}",
                )

    def test_unified_adapter_preserves_all_legacy_geometry_and_controls(self):
        assets = ROOT / "apps/electrosim/assets/g5_industrial"
        legacy_geometry = json.loads((assets / "geometry.json").read_text())
        legacy_controls = json.loads((assets / "controls.json").read_text())
        components = self.manifest["components"]

        for key, expected in legacy_geometry.items():
            component = components[key]
            actual = {
                field: component[field]
                for field in ("type", "size", "ports")
            }
            self.assertEqual(actual, expected, key)

        actual_controls = {}
        for key, component in components.items():
            for pose, cameras in component.get("controls_rects", {}).items():
                suffix = "" if pose == "default" else f"-{pose}"
                for camera, rect in cameras.items():
                    actual_controls[f"{key}{suffix}-{camera}"] = rect
        self.assertEqual(actual_controls, legacy_controls)

    def test_native_geometry_rejects_out_of_frame_service_box(self):
        invalid = copy.deepcopy(self.manifest)
        invalid["components"]["energy-meter-ac1"]["service_box"] = [0, 0, 10_000, 10]
        with self.assertRaisesRegex(ValueError, "service_box lies outside"):
            native_catalogue_specs(invalid)

    def test_crusher_geometry_requires_valid_service_terminals(self):
        invalid = copy.deepcopy(self.manifest)
        invalid["components"]["external-crusher"]["ports_7t_extra"] = []
        with self.assertRaisesRegex(ValueError, "must contain its PE point"):
            load_crusher_geometry(invalid)

    def test_boolean_schema_version_is_not_accepted_as_integer_one(self):
        invalid = copy.deepcopy(self.manifest)
        invalid["schema_version"] = True
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "manifest.json"
            path.write_text(json.dumps(invalid))
            with self.assertRaisesRegex(ValueError, "Unsupported unified geometry schema"):
                load_manifest(path)

    def test_generated_dart_catalogue_is_current(self):
        result = subprocess.run(
            [
                sys.executable,
                str(CONTRACT_ROOT / "generate_lot_geometry.py"),
                "--check",
            ],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)

    def test_all_27_models_have_existing_images_and_in_frame_ports(self):
        model_keys = set(native_catalogue_specs(self.manifest)) | {"external-crusher"}
        self.assertEqual(len(model_keys), 27)
        components = self.manifest["components"]
        for key in model_keys:
            component = components[key]
            width, height = component["size"]
            for path in component["assets"].values():
                self.assertTrue((ROOT / "apps/electrosim/assets" / path).is_file(), path)
            all_ports = list(component["ports"])
            all_ports.extend(component.get("ports_7t_extra", []))
            for x, y in all_ports:
                self.assertGreaterEqual(x, 0, key)
                self.assertGreaterEqual(y, 0, key)
                self.assertLessEqual(x, width, key)
                self.assertLessEqual(y, height, key)


if __name__ == "__main__":
    unittest.main()
