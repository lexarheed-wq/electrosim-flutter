import pathlib
import unittest
import tools.f18_g1_design_system as gate

class F18G1DesignSystemTest(unittest.TestCase):
    def setUp(self):
        self.mapping = gate.load_mapping(pathlib.Path(__file__).resolve().parents[1])

    def test_mapping_inventory(self):
        self.assertEqual(gate.validate_mapping(self.mapping), [])
        self.assertEqual(len(self.mapping["components"]["fundamental"]), 24)
        self.assertEqual(len(self.mapping["electrical"]["archetypes"]), 8)
        self.assertEqual(len(self.mapping["references"]), 4)

    def test_contrast(self):
        ui = self.mapping["tokens"]["uiColors"]
        self.assertGreaterEqual(gate.contrast_ratio(ui["textPrimary"], ui["surface"]), 4.5)
        self.assertGreaterEqual(gate.contrast_ratio(ui["onPrimary"], ui["primary"]), 4.5)
        self.assertGreaterEqual(gate.contrast_ratio(ui["textSecondary"], ui["surface"]), 4.5)

    def test_platform_font_exception(self):
        exceptions = self.mapping["exceptions"]
        self.assertTrue(any(x["id"] == "platform-font-family" and x["reason"] for x in exceptions))

    def test_drift_guard(self):
        bad = gate.find_forbidden_g1_changes([
            "apps/electrosim/lib/main.dart",
            "packages/electrosim_solver_dc/lib/src/solver.dart",
            "packages/electrosim_ui_kit/lib/src/design_tokens.dart",
        ])
        self.assertEqual(bad, [
            "apps/electrosim/lib/main.dart",
            "packages/electrosim_solver_dc/lib/src/solver.dart",
        ])

if __name__ == "__main__":
    unittest.main()
