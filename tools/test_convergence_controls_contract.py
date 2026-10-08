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

    def test_runtime_uses_protection_coordinator_for_ac(self):
        text = (ROOT / 'apps/electrosim/lib/runtime/electrosim_runtime_engine.dart').read_text(encoding='utf-8')
        compact = ''.join(text.split())
        self.assertIn('protectionCoordinator.advanceAc1', compact)
        self.assertIn('protectionCoordinator.advanceAc3', compact)
        self.assertIn('controlsEngine: electromechanicalControlEngine', text)
        self.assertIn('contactorStates: coordinated.contactors', text)

    def test_push_buttons_have_momentary_semantics(self):
        physics = (ROOT / 'packages/electrosim_domain/lib/src/component_physics_contract.dart').read_text(encoding='utf-8')
        self.assertIn("modelType: 'push_button_no'", physics)
        self.assertIn("modelType: 'push_button_nc'", physics)
        self.assertIn("controlLaw: ComponentControlLaw.momentaryNormallyOpen", physics)
        self.assertIn("controlLaw: ComponentControlLaw.momentaryNormallyClosed", physics)
        for path in (
            'packages/electrosim_solver_dc/lib/src/solver_dc.dart',
            'packages/electrosim_solver_ac/lib/src/solver_ac1.dart',
            'packages/electrosim_solver_ac/lib/src/solver_ac3.dart',
        ):
            solver = (ROOT / path).read_text(encoding='utf-8')
            self.assertIn('ComponentElectricalLaw.binarySwitch', solver)
            self.assertIn('ComponentControlLaw.momentaryNormallyOpen', solver)
            self.assertIn('ComponentControlLaw.momentaryNormallyClosed', solver)
            self.assertIn("component.controlState['pressed']", solver)

if __name__ == '__main__':
    unittest.main()
