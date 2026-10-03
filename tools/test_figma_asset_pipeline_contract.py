from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class FigmaAssetPipelineContractTest(unittest.TestCase):
    def test_registry_points_to_verified_figma_file_and_no_fake_node_ids(self):
        text = (ROOT / 'apps/electrosim/lib/figma_component_asset_registry.dart').read_text(encoding='utf-8')
        self.assertIn("sourceFileKey = 'TyYIfxMB0jPVIEcJPGsOwI'", text)
        self.assertIn('final String? figmaNodeId', text)
        self.assertNotRegex(text, r"figmaNodeId:\s*'")

    def test_component_assets_are_stateful_svg_contracts(self):
        text = (ROOT / 'apps/electrosim/lib/figma_component_asset_registry.dart').read_text(encoding='utf-8')
        self.assertIn('FigmaComponentVisualState', text)
        self.assertIn("assets/figma/components/", text)
        for state in ('normal', 'active', 'selected', 'fault'):
            self.assertIn(state, text)

    def test_terminals_are_normalized_to_artwork_not_generic_square(self):
        text = (ROOT / 'apps/electrosim/lib/figma_component_asset_registry.dart').read_text(encoding='utf-8')
        self.assertIn('required this.x', text)
        self.assertIn('required this.y', text)
        self.assertIn('assert(x >= 0 && x <= 1)', text)
        self.assertIn('assert(y >= 0 && y <= 1)', text)

if __name__ == '__main__':
    unittest.main()
