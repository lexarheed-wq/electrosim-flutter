"""Draft Blender recipe structure can be tested without Blender/Flutter."""
import importlib.util
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

    def __init__(self):
        self.objects = []

    def box(self, name, x, y, width, height, z, depth, material, r=0):
        self.objects.append((name, x, y, width, height))
        return name

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
