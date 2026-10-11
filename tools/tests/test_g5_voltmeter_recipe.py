"""Draft Blender recipe structure can be tested without Blender/Flutter."""
import importlib.util
import json
import unittest
from pathlib import Path

HERE = Path(__file__).resolve()
PATH = HERE.parents[1] / 'g5_3d_remaining/instrument_voltmeter_recipe.py'
SPEC = importlib.util.spec_from_file_location('volt_recipe', PATH)
recipe = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(recipe)


class StubGeometry:
    black = object()
    red = object()
    glass = object()
    well = object()
    steel = object()
    yellow = object()
    terminal_gray = object()
    brass = object()

    def __init__(self):
        self.objects = []

    def box(self, name, x, y, width, height, z, depth, material, r=0):
        self.objects.append((name, x, y, width, height))
        return name

    def cut(self, obj, tool):
        self.objects.append(('boolean_cut', obj, tool))

    def cyl(self, name, x, y, z, radius, depth, material):
        self.objects.append((name, x, y, radius, depth))
        return name


class VoltmeterDraftTest(unittest.TestCase):
    def test_body_aspect_ratio_and_probe_sockets(self):
        g = StubGeometry()
        recipe.build(g, {'key': recipe.KEY, 'size': recipe.SIZE})
        names = {part[0] for part in g.objects}
        self.assertTrue({'body', 'cover', 'base', 'lcd_glass',
                         'contact_0', 'contact_1',
                         'terminal_housing_com', 'terminal_housing_v_ohm'} <= names)
        body = next(part for part in g.objects if part[0] == 'body')
        self.assertAlmostEqual(body[3] / body[4], 84 / 167, places=7)
        self.assertFalse(any(name == 'contact_2' for name in names))
        self.assertEqual(sum(p[0] == 'boolean_cut' for p in g.objects), 4)

    def test_dynamic_lcd_bounds_and_probe_coordinates_fit_mesh(self):
        job = json.loads((HERE.parents[1] /
                          'g5_3d_remaining/voltmeter_construction_draft.json'
                          ).read_text())
        canvas = job['canvas_contract']
        w, h = canvas['size_logical']
        self.assertEqual((w, h), recipe.SIZE)
        bounds = canvas['lcd_glass_bounds_logical']
        geom_h = h - 4.0
        body_w = geom_h * 84.0 / 167.0
        glass_w = body_w - 25
        self.assertAlmostEqual(bounds['x'], (w - glass_w) / 2)
        self.assertAlmostEqual(bounds['y'], 19.5)
        self.assertAlmostEqual(bounds['width'], glass_w)
        self.assertAlmostEqual(bounds['height'], 25.0)
        # The text inset must stay INSIDE actual geometry, unlike the legacy
        # generic overlay (80% of 112 logical = 89.6 > glass_width).
        inset = canvas['recommended_dynamic_text_inset_logical']
        self.assertGreater(inset['x'], bounds['x'])
        self.assertGreater(inset['y'], bounds['y'])
        self.assertLess(inset['x'] + inset['width'],
                        bounds['x'] + bounds['width'])
        self.assertLess(inset['y'] + inset['height'],
                        bounds['y'] + bounds['height'])
        self.assertLess(bounds['width'], w * .8)
        probes = canvas['probe_socket_centers_logical']
        self.assertEqual(set(probes), {'COM', 'V_ohm'})
        self.assertEqual(probes['COM'], [w / 2 - 14, h - 24])
        self.assertEqual(probes['V_ohm'], [w / 2 + 14, h - 24])

    def test_cannot_reuse_other_instrument(self):
        with self.assertRaises(ValueError):
            recipe.build(StubGeometry(), {'key': 'instrument-ammeter',
                                          'size': recipe.SIZE})

    def test_requires_stable_canvas_contract(self):
        with self.assertRaises(ValueError):
            recipe.build(StubGeometry(), {'key': recipe.KEY,
                                          'size': (160, 200)})


if __name__ == '__main__':
    unittest.main()
