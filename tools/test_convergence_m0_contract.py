from pathlib import Path
import csv
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]

class ConvergenceM0ContractTest(unittest.TestCase):
    def test_reference_baseline_forbids_legacy_scenario_import(self):
        data = json.loads((ROOT / 'reference/REFERENCE_BASELINE.json').read_text(encoding='utf-8'))
        note = data['note'].lower()
        self.assertIn('no legacy example or fault scenario is imported', note)

    def test_migration_matrix_excludes_v1_library_content(self):
        with (ROOT / 'docs/f0/MIGRATION_MATRIX.csv').open(encoding='utf-8', newline='') as f:
            rows = {r['Ancienne fonctionnalité']: r for r in csv.DictReader(f)}
        ex = rows['Bibliothèque Exemples']
        faults = rows['Bibliothèque Pannes']
        for row in (ex, faults):
            text = ' '.join(row.values()).lower()
            self.assertIn('reconstruction intégrale depuis zéro', text)
            self.assertIn('aucun', text)
            self.assertIn('v1', text)
        self.assertIn('tous les items', ex['Abandon'].lower())
        self.assertIn('tous les items', faults['Abandon'].lower())

    def test_scenario_package_has_explicit_rebuild_policy(self):
        policy = (ROOT / 'packages/electrosim_scenarios/REBUILD_POLICY.md').read_text(encoding='utf-8').lower()
        self.assertIn('reconstruction intégrale depuis zéro', policy)
        self.assertIn("aucun schéma v1", policy)
        self.assertIn("aucun scénario v1", policy)
        self.assertIn('faultyCircuitState'.lower(), policy)

    def test_baseline_catalog_sources_are_marked_non_product_fixtures(self):
        for rel in (
            'packages/electrosim_scenarios/lib/src/f10_examples.dart',
            'packages/electrosim_scenarios/lib/src/f11_fault_scenarios.dart',
            'packages/electrosim_scenarios/lib/src/f16_catalog.dart',
        ):
            first = (ROOT / rel).read_text(encoding='utf-8').splitlines()[0]
            self.assertIn('BOOTSTRAP_FIXTURE_ONLY', first)

    def test_scenario_package_does_not_import_legacy_or_reference_tree(self):
        src = ROOT / 'packages/electrosim_scenarios/lib'
        forbidden = ('reference/', 'legacy/', 'fieldfix', 'electrosim_b533', 'electrosim_b539')
        for p in src.rglob('*.dart'):
            text = p.read_text(encoding='utf-8').lower()
            for token in forbidden:
                self.assertNotIn(token.lower(), text, f'{p}: forbidden dependency {token}')

    def test_fault_architecture_has_no_example_link(self):
        p = ROOT / 'packages/electrosim_scenarios/lib/src/fault_scenario_definition.dart'
        text = p.read_text(encoding='utf-8').lower()
        self.assertNotIn('exampleid', text)
        self.assertNotIn('example_id', text)
        self.assertIn('faultycircuit', text)

if __name__ == '__main__':
    unittest.main()
