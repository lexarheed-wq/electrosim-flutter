"""Crusher maintenance geometry checks; no claim of Flutter qualification."""
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'g5_3d_remaining'))
from external_crusher_recipe import KEY, SIZE, PORTS, EARTH_PORT, build
from test_g5_ammeter_mesh_contract import FakeCyclesGeometry


class Geometry(FakeCyclesGeometry):
    def material(self, name, rgb, metallic=0, **finish):
        return name

    def panel(self, name, points, material, thickness):
        self.items[name] = dict(points=points, material=material,
                                thickness=thickness)
        return name

    def tube(self, name, points, radius, material):
        self.items[name] = dict(points=points, radius=radius, material=material)
        return name

    def domed_panel(self, name, points, material, thickness, bulge):
        self.panel(name,points,material,thickness)
        self.items[name]['bulge']=bulge
        return name

    def bolt(self, name, x, y, z, radius, material):
        return self.cyl(name,x,y,z,radius,radius*.6,material)


class CrusherContract(unittest.TestCase):
    def test_winding_ports_and_earth_are_separate_and_accessible(self):
        h = Geometry()
        build(h, dict(key=KEY, size=SIZE, service_open=True))
        self.assertEqual(len(set(PORTS)), 6)
        self.assertNotIn(EARTH_PORT, PORTS)
        guard = h.items['closed_lateral_belt_guard']['points']
        self.assertEqual(len(guard), 80)
        area = sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(guard,guard[1:]+guard[:1]))
        self.assertLess(area,0, 'Solidify must extrude behind the cover front')
        self.assertGreater(h.items['closed_lateral_belt_guard']['bulge'],0)
        for i, (x, y) in enumerate(PORTS):
            stud = h.items[f'winding_stud_{i}']
            self.assertEqual((stud['x'], stud['y']), (x, y))
            self.assertLess(x, min(p[0] for p in guard))
        self.assertIn('protective_earth_stud', h.items)
        self.assertEqual(len([n for n in h.items if n.startswith('hopper_panel_')]), 4)

    def test_normal_view_keeps_live_studs_inside_closed_enclosure(self):
        h = Geometry()
        build(h, dict(key=KEY, size=SIZE))
        self.assertIn('closed_service_cover', h.items)
        self.assertIn('fixed_power_gland', h.items)
        self.assertFalse(any(n.startswith('winding_stud_') for n in h.items))
        self.assertNotIn('protective_earth_stud', h.items)

    def test_photo_verified_mechanism_and_conduits_replace_invented_wheel(self):
        h = Geometry()
        build(h, dict(key=KEY, size=SIZE))
        self.assertIn('adjustment_spindle_thread',h.items)
        self.assertIn('solid_adjustment_handwheel',h.items)
        self.assertIn('gap_locking_lever',h.items)
        self.assertIn('black_control_conduit',h.items)
        self.assertIn('grey_interlock_conduit',h.items)
        self.assertFalse(any('handwheel_spoke' in n for n in h.items))

    def test_wrong_component_is_rejected(self):
        with self.assertRaises(ValueError):
            build(Geometry(), dict(key='external-compressor', size=SIZE))


if __name__ == '__main__':
    unittest.main()
