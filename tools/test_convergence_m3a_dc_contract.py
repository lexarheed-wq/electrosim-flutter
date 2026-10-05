from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M3ADcContractTest(unittest.TestCase):
    def test_solver_uses_canonical_topology_branches(self):
        text = (ROOT / 'packages/electrosim_solver_dc/lib/src/solver_dc.dart').read_text(encoding='utf-8')
        self.assertRegex(''.join(text.split()), r'topology\.branchesForComponent\(component\.id,?\)')
        self.assertNotIn("component.terminals[0].id", text)
        self.assertNotIn("component.terminals[1].id", text)

    def test_current_limit_is_canonical_and_bounded(self):
        solver = (ROOT / 'packages/electrosim_solver_dc/lib/src/solver_dc.dart').read_text(encoding='utf-8')
        options = (ROOT / 'packages/electrosim_solver_dc/lib/src/dc_solver_options.dart').read_text(encoding='utf-8')
        self.assertIn("'currentLimitA'", solver)
        self.assertIn('sourceCurrentLimited', solver)
        self.assertIn('maxCurrentLimitIterations', options)
        self.assertNotIn("'Imax'", solver)

    def test_ratings_remain_separate(self):
        solver = (ROOT / 'packages/electrosim_solver_dc/lib/src/solver_dc.dart').read_text(encoding='utf-8')
        ratings = (ROOT / 'packages/electrosim_domain/lib/src/electrical_ratings.dart').read_text(encoding='utf-8')
        self.assertIn('receiverNominalCurrentA', ratings)
        self.assertIn('protectionRatedCurrentA', ratings)
        self.assertIn("'currentLimitA'", solver)

    def test_m3a_regression_tests_exist(self):
        test = ROOT / 'packages/electrosim_solver_dc/test/m3a_convergence_test.dart'
        text = test.read_text(encoding='utf-8')
        self.assertIn('voltage source enters bounded current regulation', text)
        self.assertIn('DC breaker is a canonical topology branch', text)
        self.assertIn('receiver nominal current is descriptive', text)

if __name__ == '__main__':
    unittest.main()
