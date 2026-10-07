import pathlib
import unittest
import tools.f18_g2a_wire_contract as gate

class WireArchitectureContractTest(unittest.TestCase):
    def setUp(self):
        self.data=gate.load_contract(pathlib.Path(__file__).resolve().parents[1])

    def test_contract_is_complete(self):
        self.assertEqual(gate.validate_contract(self.data), [])

    def test_crossings_are_avoided_then_bridged_without_rejecting_wiring(self):
        routing=self.data["routing"]
        self.assertTrue(routing["netAware"])
        self.assertTrue(routing["automaticNonJunctionCrossingsAllowed"])
        self.assertEqual(routing["crossingPolicy"], "avoid-then-bridge")
        self.assertFalse(routing["electricalConnectionMayBeRejectedForRouting"])

    def test_dc_placement_is_rectangular_and_symmetric(self):
        self.assertEqual(self.data["domains"]["dc"]["defaultLayout"], "rectangular-loop")
        self.assertTrue(self.data["domains"]["dc"]["symmetricInlinePlacement"])
        self.assertFalse(self.data["placement"]["autoPlacementAtBendAllowed"])

    def test_lane_order_is_stable(self):
        self.assertEqual(self.data["domains"]["ac1"]["laneOrder"], ["L","N","PE"])
        self.assertEqual(self.data["domains"]["ac3"]["laneOrder"], ["L1","L2","L3","N","PE"])
        self.assertEqual(self.data["domains"]["pv"]["dcPairOrder"], ["+","-"])

if __name__ == "__main__":
    unittest.main()
