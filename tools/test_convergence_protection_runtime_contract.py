from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ProtectionRuntimeContractTest(unittest.TestCase):
    def test_trip_coordination_uses_explicit_simulation_duration(self):
        text = (ROOT / 'packages/electrosim_protection/lib/src/protection_coordinator.dart').read_text(encoding='utf-8')
        self.assertIn('required Duration elapsed', text)
        self.assertNotIn('DateTime.now', text)
        self.assertNotIn('Stopwatch', text)
        self.assertIn('shouldOpenInstantaneously', text)
        self.assertIn("'tripped': device.tripped", text)

    def test_runtime_exposes_protection_state_and_advance_api(self):
        text = (ROOT / 'apps/electrosim/lib/runtime/electrosim_runtime_engine.dart').read_text(encoding='utf-8')
        self.assertIn('ProtectionRuntimeState? protectionState', text)
        self.assertIn('ProtectionCoordinator protectionCoordinator', text)
        self.assertIn('required Duration elapsed', text)
        self.assertIn('previousProtectionState', text)

    def test_ac3_solver_has_three_pole_protection_models(self):
        text = (ROOT / 'packages/electrosim_solver_ac/lib/src/solver_ac3.dart').read_text(encoding='utf-8')
        self.assertIn("'breaker_3p'", text)
        self.assertIn("'thermal_overload_3p'", text)
        self.assertIn('Ac3BranchKind.idealProtection', text)

if __name__ == '__main__':
    unittest.main()
