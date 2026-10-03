from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M7MeasurementContractTest(unittest.TestCase):
    def test_ac_measurements_are_solver_grounded(self):
        text = (ROOT / 'packages/electrosim_measurements/lib/src/measurement_engine.dart').read_text(encoding='utf-8')
        self.assertIn('Ac1SolveResult simulation', text)
        self.assertIn('Ac3SolveResult simulation', text)
        self.assertIn('simulation.nodeVoltages', text)
        self.assertIn('simulation.branchResults', text)

    def test_measurement_contract_exposes_rms_and_frequency(self):
        text = (ROOT / 'packages/electrosim_measurements/lib/src/measurement_models.dart').read_text(encoding='utf-8')
        self.assertIn('voltageAcRms', text)
        self.assertIn('currentAcRms', text)
        self.assertIn('frequency', text)

    def test_no_separate_deenergized_ui_mode_is_introduced(self):
        text = (ROOT / 'packages/electrosim_measurements/lib/src/measurement_models.dart').read_text(encoding='utf-8')
        self.assertNotIn('deenergizedMode', text)
        self.assertNotIn('powerOffMode', text)

if __name__ == '__main__':
    unittest.main()
