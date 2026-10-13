"""Offline tests: detect corrupted electrical/visual identities before 3D staging."""
import importlib.util
import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve()
TOOL = HERE.parents[1] / 'g5_remaining_3d_contract_guard.py'
SPEC = importlib.util.spec_from_file_location('g5_guard', TOOL)
guard = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(guard)


def catalogue_from(items):
    result = []
    for item in items:
        model, visual = item['electrical_model'], item['visual_model']
        extra = f"    visualModelType: '{visual}',\n" if visual != model else ''
        if item['variant'] is not None:
            extra += f"    visualVariant: '{item['variant']}',\n"
        labels = ', '.join(repr(x) for x in item['terminals'])
        result.append(
            f"  F9PaletteDefinition(\n    keyName: '{item['key']}',\n"
            f"    modelType: '{model}',\n{extra}"
            f"    kind: F9PaletteElementKind.{item['kind']},\n"
            f"    terminalLabels: <String>[{labels}],\n  ),\n"
        )
    return ''.join(result)


class G5ContractGuardTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads(guard.DEFAULT_MANIFEST.read_text())
        cls.source = catalogue_from(cls.manifest['items'])

    def test_all_26_contracts(self):
        self.assertEqual(guard.validate(self.source, self.manifest), [])

    def test_model_change(self):
        modified = self.source.replace("modelType: 'motor_3p_6t'",
                                       "modelType: 'impedance'", 1)
        self.assertTrue(any('external-crusher: electrical_model' in x
                            for x in guard.validate(modified, self.manifest)))

    def test_probes_not_regular_terminals(self):
        modified = self.source.replace("terminalLabels: <String>[],",
                                       "terminalLabels: <String>['V', 'COM'],", 1)
        self.assertTrue(any('instrument-voltmeter' in x
                            for x in guard.validate(modified, self.manifest)))

    def test_visual_variant(self):
        modified = self.source.replace("visualVariant: 'crusher'",
                                       "visualVariant: 'fan'", 1)
        self.assertTrue(any('external-crusher: variant' in x
                            for x in guard.validate(modified, self.manifest)))

    def test_duplicate_key(self):
        with self.assertRaises(ValueError):
            guard.catalogue_entries(self.source + self.source)

    def test_missing_key(self):
        modified = self.source.replace("keyName: 'impedance'",
                                       "keyName: 'missing'", 1)
        self.assertTrue(any('impedance: absent' in x
                            for x in guard.validate(modified, self.manifest)))


if __name__ == '__main__':
    unittest.main()
