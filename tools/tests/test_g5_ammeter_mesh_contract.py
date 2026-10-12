"""Local geometry contract checks; does NOT require Blender/Flutter."""
import ast
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools' / 'g5_3d_remaining'))
from instrument_ammeter_recipe import build, KEY, SIZE


class FakeCyclesGeometry:
    yellow = 'yellow'
    black = 'black'
    well = 'well'
    steel = 'steel'
    glass = 'glass'
    terminal_gray = 'gray'
    red = 'red'
    brass = 'brass'

    def __init__(self):
        self.items = {}
        self.cuts = []

    def box(self, name, x, y, width, height, z, depth, material, r=0):
        assert name not in self.items
        self.items[name] = dict(
            kind='box', x=x, y=y, width=width, height=height,
            z=z, depth=depth, material=material)
        return name

    def cyl(self, name, x, y, z, radius, depth, material):
        assert name not in self.items
        self.items[name] = dict(
            kind='cylinder', x=x, y=y, z=z, radius=radius,
            depth=depth, material=material)
        return name

    def cut(self, body, cutter):
        self.cuts.append((body, cutter))


class AmmeterGeometryTest(unittest.TestCase):
    def setUp(self):
        self.h = FakeCyclesGeometry()
        build(self.h, {'key': KEY, 'size': SIZE})

    def test_original_a_and_com_recesses(self):
        parts = self.h.items
        self.assertEqual((parts['terminal_housing_com']['x'],
                          parts['terminal_housing_com']['y']), (42, 128))
        self.assertEqual((parts['terminal_housing_current_a']['x'],
                          parts['terminal_housing_current_a']['y']), (70, 128))
        self.assertEqual(parts['terminal_housing_com']['material'], 'black')
        self.assertEqual(parts['terminal_housing_current_a']['material'], 'red')
        self.assertEqual(
            sorted(k for k in parts if k.startswith('terminal_housing_')),
            ['terminal_housing_com', 'terminal_housing_current_a'])
        self.assertEqual(len(self.h.cuts), 4)

    def test_four_real_buttons_selector_and_fuse(self):
        p = self.h.items
        self.assertEqual([p[f'key_{i}']['x'] for i in range(4)],
                         [35, 49, 63, 77])
        self.assertEqual((p['selector_shaft']['x'],
                          p['selector_shaft']['y']), (53, 86))
        self.assertEqual((p['fuse_hatch']['x'],
                          p['fuse_hatch']['y']), (53, 114))
        self.assertEqual(p['fuse_hatch']['height'], 8.5)
        self.assertLess(86 + 21, p['fuse_hatch']['y'] - p['fuse_hatch']['height'] / 2)
        self.assertEqual(len([k for k in p if k.startswith('selector_detent_')]),
                         11)

    def test_lcd_inset_from_actual_glass(self):
        glass = self.h.items['lcd_glass']
        rect = (glass['x'] - glass['width'] / 2,
                glass['y'] - glass['height'] / 2,
                glass['x'] + glass['width'] / 2,
                glass['y'] + glass['height'] / 2)
        self.assertEqual(rect, (31, 21, 81, 45))
        self.assertTrue(rect[0] < 34 < 78 < rect[2])
        self.assertTrue(rect[1] < 24 < 42 < rect[3])

    def test_fuse_clearance_to_two_sockets(self):
        p = self.h.items
        fuse = p['fuse_hatch']
        com = p['terminal_housing_com']
        self.assertLess(fuse['y'] + fuse['height'] / 2,
                        com['y'] - com['radius'])

    def test_reject_wrong_identity_or_canvas_size(self):
        for job in [
            {'key': 'instrument-voltmeter', 'size': SIZE},
            {'key': KEY, 'size': (100, 100)},
        ]:
            with self.assertRaises(ValueError):
                build(FakeCyclesGeometry(), job)

    def test_manifest_keeps_probe_ports_outside_power_graph(self):
        meta = json.loads((ROOT / 'tools' / 'g5_3d_remaining' /
                          'instrument_ammeter_construction.json').read_text())
        self.assertFalse(meta['physics']['ports_as_circuit_terminals'])
        self.assertEqual(
            [p['instrument_port'] for p in meta['connectors']],
            ['InstrumentPort.common', 'InstrumentPort.amp'])
        self.assertFalse(meta['merge_allowed'])
        self.assertFalse(meta['reference']['dimensions_mm_verified'])

    def test_blender_runner_syntax_without_blender(self):
        render = ROOT / 'tools' / 'g5_3d_remaining' / 'render_voltmeter_cycles.py'
        source = render.read_text()
        ast.parse(source, filename=str(render))
        self.assertIn("jack_legend_y = 143.0 if KEY == 'instrument-ammeter'", source)
        self.assertIn("'fuse-panel-legend', 'FUSE'", source)
        self.assertNotIn("'FUSE 10 A'", source)
        self.assertIn("f'holster-grip-{side}-{i}'", source)
        self.assertNotIn("f'grip-rib-{i}'", source)


if __name__ == '__main__':
    unittest.main(verbosity=2)
