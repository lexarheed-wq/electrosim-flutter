from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
DOMAIN = ROOT / 'packages/electrosim_domain/lib/src/component_model_contract.dart'
TYPES = ROOT / 'packages/electrosim_domain/lib/src/electrical_types.dart'
ENGINE = ROOT / 'packages/electrosim_topology/lib/src/topology_engine.dart'
GRAPH = ROOT / 'packages/electrosim_topology/lib/src/topology_graph.dart'
FINDING = ROOT / 'packages/electrosim_topology/lib/src/topology_finding.dart'
DOMAIN_TEST = ROOT / 'packages/electrosim_domain/test/component_model_contract_test.dart'
TOPO_TEST = ROOT / 'packages/electrosim_topology/test/topology_engine_test.dart'

class ConvergenceM1BM2ContractTest(unittest.TestCase):
    def test_component_contract_is_solver_and_ui_independent(self):
        text = DOMAIN.read_text(encoding='utf-8')
        self.assertIn('final class ComponentModelContract', text)
        self.assertIn('final class ComponentModelRegistry', text)
        self.assertNotIn('electrosim_solver', text)
        self.assertNotIn('package:flutter', text)

    def test_explicit_contactor_and_three_pole_contracts_exist(self):
        text = DOMAIN.read_text(encoding='utf-8')
        self.assertIn("modelType: 'contactor_3p'", text)
        self.assertIn("modelType: 'contactor_ac1'", text)
        self.assertIn("modelType: 'breaker_3p'", text)
        self.assertIn("modelType: 'thermal_overload_3p'", text)
        self.assertIn("id: 'control:coil'", text)
        self.assertIn("id: 'power:L1'", text)
        self.assertIn("id: 'power:L2'", text)
        self.assertIn("id: 'power:L3'", text)

    def test_no_legacy_model_aliases_are_registered(self):
        text = DOMAIN.read_text(encoding='utf-8')
        for legacy in ("modelType: 'breakerDC'", "modelType: 'breaker3p'", "modelType: 'contactor3p'", "modelType: 'thermal3p'"):
            self.assertNotIn(legacy, text)
        test = DOMAIN_TEST.read_text(encoding='utf-8')
        self.assertIn('canonical registry does not add legacy V1 aliases', test)

    def test_terminal_vocabulary_has_line_load_and_coil_roles(self):
        text = TYPES.read_text(encoding='utf-8')
        for role in ('lineL1', 'lineL2', 'lineL3', 'loadT1', 'loadT2', 'loadT3', 'coilA1', 'coilA2'):
            self.assertIn(role, text)

    def test_topology_projects_branches_without_unioning_them(self):
        engine = ENGINE.read_text(encoding='utf-8')
        graph = GRAPH.read_text(encoding='utf-8')
        self.assertIn('final List<TopologyBranch> componentBranches', engine)
        self.assertIn('TopologyBranch(', engine)
        self.assertIn('final class TopologyBranch', graph)
        self.assertNotIn('unionFind.union(fromTerminal.id, toTerminal.id)', engine)
        self.assertNotIn('unionFind.union(toTerminal.id, fromTerminal.id)', engine)

    def test_contract_mismatch_and_mode_mismatch_are_explicit_findings(self):
        text = FINDING.read_text(encoding='utf-8')
        self.assertIn('componentContractMismatch', text)
        self.assertIn('componentModeMismatch', text)
        tests = TOPO_TEST.read_text(encoding='utf-8')
        self.assertIn('contract mismatch is an explicit blocking finding', tests)
        self.assertIn('wrong electrical mode is reported explicitly', tests)

    def test_topology_tests_cover_contactor_poles_and_coil(self):
        text = TOPO_TEST.read_text(encoding='utf-8')
        self.assertIn('three-phase contactor projects three power poles and one coil without merging nodes', text)
        self.assertIn("TerminalRole.coilA1", text)
        self.assertIn("TerminalRole.coilA2", text)
        self.assertIn('ElectricalBranchRole.powerPole', text)
        self.assertIn('ElectricalBranchRole.controlCoil', text)

if __name__ == '__main__':
    unittest.main()
