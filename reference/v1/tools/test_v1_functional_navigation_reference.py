import json
import unittest
from pathlib import Path

V1_ROOT = Path(__file__).resolve().parents[1]
CONTRACT = V1_ROOT / "v1_functional_navigation_contract.json"

class V1ReferenceContractTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(CONTRACT.read_text(encoding="utf-8"))
        cls.states = {s["id"]: s for s in cls.data["canonical_states"]}

    def test_scope_does_not_force_v1_theme(self):
        self.assertEqual(self.data["scope"], "functional_navigation")
        self.assertIn("current_flutter_theme_is_allowed", self.data["theme_policy"])

    def test_core_navigation_states_exist(self):
        required = {
            "HOME", "CREATE_SESSION_DIALOG", "WAITING_ROOM", "TEACHER_DASHBOARD",
            "CABLING_ACTIVITY_SETUP", "SUPERVISION", "MAINTENANCE_CENTER",
            "STUDENT_SITUATION_VALIDATION", "DESIGN_CENTER", "WORKSHOP"
        }
        self.assertTrue(required.issubset(self.states))

    def test_observed_edges_are_well_formed(self):
        for edge in self.data["observed_transitions"]:
            self.assertIn(edge["from"], self.states)
            self.assertIn(edge["to"], self.states)
            self.assertTrue(edge["action"])

    def test_frames_have_fixed_fingerprints(self):
        self.assertEqual(len(self.data["source"]["sha256"]), 64)
        for state in self.states.values():
            self.assertEqual(len(state["frame_sha256"]), 64, state["id"])
            self.assertGreaterEqual(state["timestamp_seconds"], 0)

    def test_required_entry_points_are_recorded(self):
        affordances = {
            (sid, action)
            for sid, state in self.states.items()
            for action in state["required_affordances"]
        }
        required = {
            ("HOME", "create_session"),
            ("HOME", "open_maintenance_center"),
            ("HOME", "open_design_center"),
            ("TEACHER_DASHBOARD", "open_cabling"),
            ("TEACHER_DASHBOARD", "open_fault_diagnosis"),
            ("TEACHER_DASHBOARD", "open_supervision"),
        }
        self.assertTrue(required.issubset(affordances))

if __name__ == "__main__":
    unittest.main()
