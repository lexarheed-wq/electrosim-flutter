from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M3BPaletteEngineContractTest(unittest.TestCase):
    def test_palette_uses_canonical_protection_types(self):
        text = (ROOT / 'apps/electrosim/lib/f9_component_palette.dart').read_text(encoding='utf-8')
        self.assertIn("modelType: 'breaker_dc'", text)
        self.assertIn("modelType: 'fuse_dc'", text)
        self.assertNotIn("modelType: 'breaker',", text)
        self.assertNotIn("modelType: 'fuse',", text)

    def test_palette_defaults_create_valid_protections(self):
        text = (ROOT / 'apps/electrosim/lib/main.dart').read_text(encoding='utf-8')
        self.assertIn("ProtectionRating.ratedCurrentKey: 10.0", text)
        self.assertIn("'fuse' => const <String, Object?>{'closed': true, 'tripped': false}", text)

    def test_solver_supports_non_diode_dc_palette_models(self):
        physics = (ROOT / 'packages/electrosim_domain/lib/src/component_physics_contract.dart').read_text(encoding='utf-8')
        structure = (ROOT / 'packages/electrosim_domain/lib/src/component_model_contract.dart').read_text(encoding='utf-8')
        solver = (ROOT / 'packages/electrosim_solver_dc/lib/src/solver_dc.dart').read_text(encoding='utf-8')
        for model in ('push_button_no', 'buzzer', 'fan_dc', 'motor_dc', 'relay_coil'):
            self.assertIn(f"modelType: '{model}'", physics)
            self.assertIn(f"modelType: '{model}'", structure)
        self.assertIn('CoreComponentPhysicsContracts', solver)
        self.assertIn('ComponentElectricalLaw.binarySwitch', solver)
        self.assertIn('ComponentElectricalLaw.resistive', solver)

    def test_relay_terminal_semantics_are_canonical(self):
        text = (ROOT / 'apps/electrosim/lib/main.dart').read_text(encoding='utf-8')
        self.assertIn("TerminalRole.coilA1", text)
        self.assertIn("TerminalRole.coilA2", text)

if __name__ == '__main__':
    unittest.main()
