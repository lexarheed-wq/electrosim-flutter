from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class SimulationClockContractTest(unittest.TestCase):
    def test_clock_uses_fixed_explicit_step_not_wall_elapsed(self):
        text = (ROOT / 'apps/electrosim/lib/runtime/electrosim_simulation_controller.dart').read_text(encoding='utf-8')
        self.assertIn('Timer.periodic(fixedStep', text)
        self.assertIn('advance(fixedStep)', text)
        self.assertNotIn('DateTime.now', text)
        self.assertNotIn('Stopwatch', text)

    def test_clock_carries_dynamic_states(self):
        text = (ROOT / 'apps/electrosim/lib/runtime/electrosim_simulation_controller.dart').read_text(encoding='utf-8')
        self.assertIn('previousProtectionState: _snapshot.protectionState', text)
        self.assertIn('previousContactorStates: _currentContactorStates()', text)

    def test_runtime_accepts_previous_contactor_state(self):
        text = (ROOT / 'apps/electrosim/lib/runtime/electrosim_runtime_engine.dart').read_text(encoding='utf-8')
        self.assertIn('previousContactorStates', text)
        self.assertIn('previousContactorStates: previousContactorStates', text)

if __name__ == '__main__':
    unittest.main()
