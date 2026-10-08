from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M4Ac1ContractTest(unittest.TestCase):
    def test_ac1_solver_uses_topology_branches(self):
        text = (ROOT / 'packages/electrosim_solver_ac/lib/src/solver_ac1.dart').read_text(encoding='utf-8')
        self.assertRegex(''.join(text.split()), r'topology\.branchesForComponent\(component\.id,?\)')
        self.assertNotIn('component.terminals[0].id', text)
        self.assertNotIn('component.terminals[1].id', text)

    def test_ac1_canonical_models_are_explicit(self):
        physics = (ROOT / 'packages/electrosim_domain/lib/src/component_physics_contract.dart').read_text(encoding='utf-8')
        solver = (ROOT / 'packages/electrosim_solver_ac/lib/src/solver_ac1.dart').read_text(encoding='utf-8')
        for model in ('lamp', 'inductor', 'capacitor', 'impedance', 'switch', 'breaker_ac1', 'fuse_ac1'):
            self.assertIn(f"modelType: '{model}'", physics)
        self.assertIn('CoreComponentPhysicsContracts', solver)
        for law in ('resistive', 'inductor', 'capacitor', 'acImpedance', 'binarySwitch', 'protectionSwitch'):
            self.assertIn(f'ComponentElectricalLaw.{law}', solver)

    def test_ac_passives_have_domain_contracts(self):
        text = (ROOT / 'packages/electrosim_domain/lib/src/component_model_contract.dart').read_text(encoding='utf-8')
        for model in ('inductor', 'capacitor', 'impedance'):
            self.assertIn(f"modelType: '{model}'", text)

    def test_m4_regression_tests_exist(self):
        text = (ROOT / 'packages/electrosim_solver_ac/test/m4_ac1_convergence_test.dart').read_text(encoding='utf-8')
        self.assertIn('lamp uses canonical topology branch', text)
        self.assertIn('switch state opens or closes', text)
        self.assertIn('tripped AC1 breaker', text)

if __name__ == '__main__':
    unittest.main()
