from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M8PvEnergyContractTest(unittest.TestCase):
    def test_shading_is_bounded_and_reduces_effective_irradiance(self):
        text = (ROOT / 'packages/electrosim_pv/lib/src/solver_pv.dart').read_text(encoding='utf-8')
        self.assertIn("'shadingPct'", text)
        self.assertIn('1.0 - shadingPct / 100.0', text)
        self.assertIn('_boundedPercentageSetting', text)

    def test_energy_uses_explicit_elapsed_duration_only(self):
        text = (ROOT / 'packages/electrosim_energy/lib/src/energy_engine.dart').read_text(encoding='utf-8')
        self.assertIn('required Duration elapsed', text)
        self.assertNotIn('DateTime.now', text)
        self.assertNotIn('Stopwatch', text)

    def test_pv_faulted_inverter_has_physical_zero_output_test(self):
        text = (ROOT / 'packages/electrosim_pv/test/solver_pv_test.dart').read_text(encoding='utf-8')
        self.assertIn('inverter fault conditions stop downstream output physically', text)
        self.assertIn('M8 shading reduces effective irradiance', text)

if __name__ == '__main__':
    unittest.main()
