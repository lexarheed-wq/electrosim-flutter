from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M6DeviceProtectionContractTest(unittest.TestCase):
    def test_receiver_thresholds_are_explicit(self):
        text = (ROOT / 'packages/electrosim_measurements/lib/src/receiver_load_state.dart').read_text(encoding='utf-8')
        self.assertIn('ratio > 1.5', text)
        self.assertIn('ratio > 1.05', text)
        self.assertIn('ratio < 0.75', text)
        self.assertIn('ReceiverNominalRating.currentKey', text)

    def test_protection_uses_canonical_rating(self):
        text = (ROOT / 'packages/electrosim_measurements/lib/src/protection_dynamics.dart').read_text(encoding='utf-8')
        self.assertIn('ProtectionRating.ratedCurrentKey', text)
        self.assertNotIn("'Imax'", text)
        self.assertIn('ProtectionTripCurve.c', text)
        self.assertIn('ProtectionTripCurve.fuse', text)
        self.assertIn('ProtectionTripCurve.thermal', text)

    def test_protection_dynamics_is_pure(self):
        text = (ROOT / 'packages/electrosim_measurements/lib/src/protection_dynamics.dart').read_text(encoding='utf-8')
        self.assertNotIn('.controlState[', text)
        self.assertNotIn('CircuitState(', text)
        self.assertIn('ProtectionExposureState advance', text)

    def test_m6_regressions_cover_coordination(self):
        text = (ROOT / 'packages/electrosim_measurements/test/m6_load_protection_test.dart').read_text(encoding='utf-8')
        self.assertIn('receiver rating is independent from protection rating', text)
        self.assertIn('5 A breaker at 4.59 A remains armed', text)
        self.assertIn('exposure integrates simulation time', text)

if __name__ == '__main__':
    unittest.main()
