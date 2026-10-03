from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M10TpFlowContractTest(unittest.TestCase):
    def test_student_ui_cannot_start_published_tp(self):
        text = (ROOT / 'apps/electrosim/lib/f17_tp_session_dialog.dart').read_text(encoding='utf-8')
        self.assertIn("Key('tp-teacher-start')", text)
        self.assertIn("Key('tp-student-waiting-start')", text)
        self.assertNotIn("Key('tp-student-start')", text)

    def test_lan_host_rejects_student_start_authority(self):
        text = (ROOT / 'apps/electrosim/lib/runtime/electrosim_lan_sync.dart').read_text(encoding='utf-8')
        self.assertIn('Le professeur doit démarrer le TP', text)
        self.assertNotIn('current = controller.startStudent();', text)

    def test_submission_remains_read_only_and_teacher_score_exists(self):
        engine = (ROOT / 'packages/electrosim_tp/lib/src/tp_models.dart').read_text(encoding='utf-8')
        controller = (ROOT / 'apps/electrosim/lib/runtime/electrosim_tp_session_controller.dart').read_text(encoding='utf-8')
        self.assertIn('lifecycle == TpLifecycle.submitted', engine)
        self.assertIn('evaluateTeacher({int? score})', controller)
        self.assertIn('cancelTeacher()', controller)

    def test_tp_scenario_library_is_not_v1_migrated(self):
        policy = (ROOT / 'packages/electrosim_scenarios/REBUILD_POLICY.md').read_text(encoding='utf-8').lower()
        self.assertIn('aucun scénario v1', policy)

if __name__ == '__main__':
    unittest.main()
