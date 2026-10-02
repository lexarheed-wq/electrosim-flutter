from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
RATINGS = ROOT / 'packages/electrosim_domain/lib/src/electrical_ratings.dart'
BARREL = ROOT / 'packages/electrosim_domain/lib/electrosim_domain.dart'
TEST = ROOT / 'packages/electrosim_domain/test/electrical_ratings_test.dart'

class ConvergenceM1DomainContractTest(unittest.TestCase):
    def test_rating_contract_exists_and_is_exported(self):
        self.assertTrue(RATINGS.exists())
        self.assertIn("export 'src/electrical_ratings.dart';", BARREL.read_text())

    def test_receiver_and_protection_currents_are_distinct(self):
        text = RATINGS.read_text()
        self.assertIn("receiverNominalCurrentA", text)
        self.assertIn("protectionRatedCurrentA", text)
        self.assertIn('final class ReceiverNominalRating', text)
        self.assertIn('final class ProtectionRating', text)

    def test_no_automatic_legacy_aliases_in_domain_contract(self):
        text = RATINGS.read_text()
        self.assertNotIn("'ratedCurrent'", text)
        self.assertNotIn("'Imax'", text)

    def test_domain_contract_does_not_import_solver_or_ui(self):
        text = RATINGS.read_text()
        self.assertNotIn('electrosim_solver', text)
        self.assertNotIn('package:flutter', text)
        self.assertNotIn('electrosim_ui', text)

    def test_tests_assert_independent_quantities(self):
        text = TEST.read_text()
        self.assertIn('receiver nominal current and protection calibre are independent', text)
        self.assertIn("receiverNominalCurrentA", text)
        self.assertIn("protectionRatedCurrentA", text)

if __name__ == '__main__':
    unittest.main()
