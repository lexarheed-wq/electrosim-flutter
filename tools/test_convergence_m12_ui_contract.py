from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class M12UiContractTest(unittest.TestCase):
    def test_topbar_keeps_primary_actions_and_groups_secondary_actions(self):
        text = (ROOT / 'apps/electrosim/lib/main.dart').read_text(encoding='utf-8')
        for key in (
            'session-home-action',
            'session-dashboard-action',
            'session-manage-action',
            'workspace-rotate-action',
            'workspace-delete-action',
            'workspace-more-actions',
        ):
            self.assertIn(key, text)
        self.assertIn('PopupMenuButton<_WorkspaceSecondaryAction>', text)

    def test_workspace_shell_has_compact_medium_expanded_layouts(self):
        text = (ROOT / 'packages/electrosim_ui_kit/lib/src/workspace_shell.dart').read_text(encoding='utf-8')
        self.assertIn('ElectroSimWindowClass.compact', text)
        self.assertIn('ElectroSimWindowClass.medium', text)
        self.assertIn('ElectroSimWindowClass.expanded', text)
        self.assertIn('electroSimCompactActionsKey', text)

    def test_palette_collapsed_limit_remains_five(self):
        text = (ROOT / 'apps/electrosim/lib/f9_component_palette.dart').read_text(encoding='utf-8')
        self.assertIn('static const int _collapsedLimit = 5;', text)
        self.assertIn('palette-search-field', text)

if __name__ == '__main__':
    unittest.main()
