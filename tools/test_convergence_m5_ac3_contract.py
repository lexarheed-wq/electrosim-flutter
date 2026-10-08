from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M5Ac3ContractTest(unittest.TestCase):
    def test_ac3_power_components_use_topology_branches(self):
        text = (ROOT / 'packages/electrosim_solver_ac/lib/src/solver_ac3.dart').read_text(encoding='utf-8')
        self.assertRegex(''.join(text.split()), r'topology\.branchesForComponent\(component\.id,?\)')
        self.assertNotIn('component.terminals[0].id', text)
        self.assertNotIn('component.terminals[1].id', text)

    def test_phase_sequence_probe_path_is_preserved(self):
        text = (ROOT / 'packages/electrosim_solver_ac/lib/src/solver_ac3.dart').read_text(encoding='utf-8')
        self.assertIn("component.modelType == 'phase_sequence_probe'", text)
        self.assertIn('_Ac3Probe(', text)

    def test_ac3_switch_and_lamp_are_explicit(self):
        physics = (ROOT / 'packages/electrosim_domain/lib/src/component_physics_contract.dart').read_text(encoding='utf-8')
        solver = (ROOT / 'packages/electrosim_solver_ac/lib/src/solver_ac3.dart').read_text(encoding='utf-8')
        self.assertIn("modelType: 'lamp'", physics)
        self.assertIn("modelType: 'switch'", physics)
        self.assertIn('ComponentElectricalLaw.resistive', solver)
        self.assertIn('ComponentElectricalLaw.binarySwitch', solver)
        self.assertIn('Ac3BranchKind.idealSwitch', solver)
        self.assertIn('_closedFromControlLawAc3', solver)

    def test_m5_tests_cover_balance_and_switching(self):
        text = (ROOT / 'packages/electrosim_solver_ac/test/m5_ac3_convergence_test.dart').read_text(encoding='utf-8')
        self.assertIn('balanced star', text)
        self.assertIn('single-pole AC3 switch', text)

if __name__ == '__main__':
    unittest.main()
