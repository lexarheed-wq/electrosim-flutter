from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M9DiagnosticContractTest(unittest.TestCase):
    def test_diagnostics_cover_dc_ac1_ac3(self):
        text = (ROOT / 'packages/electrosim_diagnostics/lib/src/diagnostic_engine.dart').read_text(encoding='utf-8')
        self.assertIn('DiagnosticReport analyzeAc1', text)
        self.assertIn('DiagnosticReport analyzeAc3', text)
        self.assertIn('sourceCurrentLimited', text)
        self.assertIn('receiverLoadStates', text)
        self.assertIn('phaseLoss', text)

    def test_runtime_no_longer_silences_ac_diagnostics(self):
        text = (ROOT / 'apps/electrosim/lib/runtime/electrosim_runtime_engine.dart').read_text(encoding='utf-8')
        self.assertIn('diagnosticEngine.analyzeAc1', text)
        self.assertIn('diagnosticEngine.analyzeAc3', text)

    def test_advice_remains_evidence_backed(self):
        models = (ROOT / 'packages/electrosim_diagnostics/lib/src/diagnostic_models.dart').read_text(encoding='utf-8')
        self.assertIn('An EIE advice must cite at least one evidenceId', models)
        self.assertIn('Every EIE advice must reference evidence present in the report', models)

if __name__ == '__main__':
    unittest.main()
