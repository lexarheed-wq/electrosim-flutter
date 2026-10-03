import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]

class Point3MacLauncherContractTest(unittest.TestCase):
    def test_macos_launchers_apply_and_verify_lan_entitlements(self):
        for rel in ("run_visual.sh", "tools/run_macos_test.sh"):
            text = (ROOT / rel).read_text(encoding="utf-8")
            self.assertIn(
                'f17_apply_lan_platform_config.py" "$APP" macos',
                text,
                rel,
            )
            self.assertIn(
                'f17_apply_lan_platform_config.py" "$APP" macos --check',
                text,
                rel,
            )

    def test_visual_runner_copies_complete_package_workspace(self):
        text = (ROOT / "run_visual.sh").read_text(encoding="utf-8")
        self.assertIn('cp -R "$ROOT/packages" "$TMP_ROOT/packages"', text)
        self.assertNotIn(
            'for PKG in electrosim_domain electrosim_canvas electrosim_ui_kit',
            text,
        )

if __name__ == "__main__":
    unittest.main()
