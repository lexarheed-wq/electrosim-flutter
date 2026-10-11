"""Crusher maintenance geometry checks; no claim of Flutter qualification."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'g5_3d_remaining'))
from external_crusher_recipe import KEY, SIZE, PORTS, EARTH_PORT, build
from test_g5_ammeter_mesh_contract import FakeCyclesGeometry


class Geometry(FakeCyclesGeometry):
    def material(self, name, rgb, metallic=0):
        return name

    def panel(self, name, points, material, thickness):
        self.items[name] = dict(points=points, material=material,
                                thickness=thickness)
        return name


class CrusherContract(unittest.TestCase):
    def test_winding_ports_and_earth_are_separate_and_accessible(self):
        h = Geometry()
        build(h, dict(key=KEY, size=SIZE))
        self.assertEqual(len(set(PORTS)), 6)
        self.assertNotIn(EARTH_PORT, PORTS)
        guard = h.items['closed_lateral_belt_guard']['points']
        self.assertEqual(len(guard), 80)
        for i, (x, y) in enumerate(PORTS):
            stud = h.items[f'winding_stud_{i}']
            self.assertEqual((stud['x'], stud['y']), (x, y))
            self.assertLess(x, min(p[0] for p in guard))
        self.assertIn('protective_earth_stud', h.items)
        self.assertEqual(len([n for n in h.items if n.startswith('hopper_panel_')]), 4)

    def test_wrong_component_is_rejected(self):
        with self.assertRaises(ValueError):
            build(Geometry(), dict(key='external-compressor', size=SIZE))


if __name__ == '__main__':
    unittest.main()
