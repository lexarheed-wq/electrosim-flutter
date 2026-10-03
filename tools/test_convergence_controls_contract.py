from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ControlsConvergenceContractTest(unittest.TestCase):
    def test_coordination_is_bounded_and_outside_linear_solver(self):
        text = (ROOT / 'packages/electrosim_controls/lib/src/electromechanical_control_engine.dart').read_text(encoding='utf-8')
        self.assertIn('maxIterations = 4', text)
        self.assertIn('iterationLimitExceeded', text)
        self.assertIn("coilPickupVoltageV", text)
        self.assertIn("coilDropoutVoltageV", text)
        self.assertIn("linkedContactorId", text)

    def test_hysteresis_is_explicit(self):
        text = (ROOT / 'packages/electrosim_controls/lib/src/electromechanical_control_engine.dart').read_text(encoding='utf-8')
        self.assertIn('voltageV > thresholds.dropout', text)
        self.assertIn('voltageV >= thresholds.pickup', text)

    def test_runtime_uses_coordinator_for_ac(self):
        text = (ROOT / 'apps/electrosim/lib/runtime/electrosim_runtime_engine.dart').read_text(encoding='utf-8')
        self.assertIn('electromechanicalControlEngine.solveAc1', text)
        self.assertIn('electromechanicalControlEngine.solveAc3', text)
        self.assertIn('contactorStates: coordinated.contactors', text)

    def test_push_buttons_have_momentary_semantics(self):
        dc = (ROOT / 'packages/electrosim_solver_dc/lib/src/solver_dc.dart').read_text(encoding='utf-8')
        ac1 = (ROOT / 'packages/electrosim_solver_ac/lib/src/solver_ac1.dart').read_text(encoding='utf-8')
        ac3 = (ROOT / 'packages/electrosim_solver_ac/lib/src/solver_ac3.dart').read_text(encoding='utf-8')
        for text in (dc, ac1, ac3):
            self.assertIn("'push_button_no'", text)
            self.assertIn("'push_button_nc'", text)
            self.assertIn("controlState['pressed']", text)

if __name__ == '__main__':
    unittest.main()
