from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M11VisualContractTest(unittest.TestCase):
    def test_palette_and_canvas_share_f18_painter(self):
        palette = (ROOT / 'apps/electrosim/lib/f9_component_palette.dart').read_text(encoding='utf-8')
        overlay = (ROOT / 'apps/electrosim/lib/f9_component_visuals.dart').read_text(encoding='utf-8')
        self.assertIn('F18ComponentArchetypeGlyph', palette)
        self.assertIn('paintF18ElectricalArchetype', overlay)

    def test_specific_models_have_dedicated_visual_paths(self):
        text = (ROOT / 'apps/electrosim/lib/f18_component_archetypes.dart').read_text(encoding='utf-8')
        for model in (
            'dc_voltage_source', 'resistor', 'lamp', 'push_button_no',
            'breaker_dc', 'fuse_dc', 'diode', 'relay_coil',
            'motor_dc', 'fan_dc', 'buzzer',
        ):
            self.assertIn(model, text)

    def test_canvas_no_longer_prints_raw_model_type(self):
        text = (ROOT / 'packages/electrosim_canvas/lib/src/circuit_scene_painter.dart').read_text(encoding='utf-8')
        self.assertNotIn('text: modelType', text)
        self.assertIn('does not paint raw model', text)

    def test_f18_app_owns_component_chrome_once(self):
        app = (ROOT / 'apps/electrosim/lib/main.dart').read_text(encoding='utf-8')
        painter = (ROOT / 'apps/electrosim/lib/f18_component_archetypes.dart').read_text(encoding='utf-8')
        overlay = (ROOT / 'apps/electrosim/lib/f9_component_visuals.dart').read_text(encoding='utf-8')
        self.assertIn('paintElementChrome: false', app)
        self.assertIn('_paintIndustrialModel', painter)
        self.assertIn('worldRect.width * scale', overlay)

if __name__ == '__main__':
    unittest.main()
