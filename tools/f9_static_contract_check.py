#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

required = [
    'packages/electrosim_ui_kit/pubspec.yaml',
    'packages/electrosim_ui_kit/lib/electrosim_ui_kit.dart',
    'packages/electrosim_ui_kit/lib/src/design_tokens.dart',
    'packages/electrosim_ui_kit/lib/src/electrosim_theme.dart',
    'packages/electrosim_ui_kit/lib/src/responsive.dart',
    'packages/electrosim_ui_kit/lib/src/workspace_shell.dart',
    'packages/electrosim_ui_kit/test/design_system_test.dart',
    'apps/electrosim/lib/f9_component_palette.dart',
    'apps/electrosim/lib/f9_auto_placement.dart',
    'apps/electrosim/lib/f9_element_editor.dart',
    'apps/electrosim/lib/f9_wiring_policy.dart',
    'apps/electrosim/lib/f9_component_visuals.dart',
    'apps/electrosim/lib/f9_context_panels.dart',
    'apps/electrosim/lib/f9_ui_context.dart',
    'apps/electrosim/test/f9_shell_test.dart',
    'apps/electrosim/test/f9_wiring_policy_test.dart',
    'apps/electrosim/test/f9_goldens_test.dart',
    'tools/approve_f9_goldens.py',
    'review_f9_goldens.sh',
    'reference/f8/F8_VALIDATION.json',
]
for rel in required:
    if not (ROOT / rel).is_file():
        errors.append(f'missing:{rel}')

responsive = (ROOT / 'packages/electrosim_ui_kit/lib/src/responsive.dart').read_text(encoding='utf-8')
for token in ['compactUpperBound = 600', 'mediumUpperBound = 1000', 'compact, medium, expanded']:
    if token not in responsive:
        errors.append(f'responsive-contract:{token}')

main = (ROOT / 'apps/electrosim/lib/main.dart').read_text(encoding='utf-8')
home = (ROOT / 'apps/electrosim/lib/f18_home.dart').read_text(encoding='utf-8')
main_surface = main + '\n' + home
for label in [
    'Créer une nouvelle session', 'Centre de maintenance', 'Centre de conception',
    'Accueil', 'Tableau de bord', 'Câblage', 'Recherche de dérangement',
    'Supervision', 'Gérer la session',
]:
    if label not in main_surface:
        errors.append(f'ux-label-missing:{label}')
for token in [
    'session-home-action', 'session-dashboard-action', 'session-manage-action',
    'dashboard-wiring', 'dashboard-troubleshooting', 'dashboard-supervision',
    'CallbackShortcuts', 'LogicalKeyboardKey.escape', 'F9CanvasVisualOverlay',
    '_handleConnectionRequested', '_replaceSelectedElement', 'F9ContextPanels',
]:
    if token not in main:
        errors.append(f'final-main-contract:{token}')

shell = (ROOT / 'packages/electrosim_ui_kit/lib/src/workspace_shell.dart').read_text(encoding='utf-8')
for token in [
    'ElectroSimWindowClass.compact', 'ElectroSimWindowClass.medium',
    'electroSimCanvasRegionKey', 'ElectroSimBreakpoints.classify',
]:
    if token not in shell:
        errors.append(f'shell-contract:{token}')
if 'ElectroSimWindowClass.expanded' not in responsive:
    errors.append('shell-contract:expanded-window-class')

freeze = json.loads((ROOT / 'docs/f9/F8_CORE_FREEZE_FOR_F9.json').read_text(encoding='utf-8'))
if freeze.get('fileCount') != 54:
    errors.append(f"f8-core-freeze-count:{freeze.get('fileCount')}")

palette = (ROOT / 'apps/electrosim/lib/f9_component_palette.dart').read_text(encoding='utf-8')
for token in [
    'palette-search-field', 'palette-show-all', 'Draggable<F9PaletteDefinition>',
    'F9ComponentPreview', 'palette-quick-add-', 'F18ComponentAssetVisual',
]:
    if token not in palette:
        errors.append(f'palette-contract:{token}')

editor = (ROOT / 'apps/electrosim/lib/f9_element_editor.dart').read_text(encoding='utf-8')
for token in ['describe', 'togglePrimaryState', 'deleteElement', 'replaceComponent']:
    if token not in editor:
        errors.append(f'editor-contract:{token}')

wiring = (ROOT / 'apps/electrosim/lib/f9_wiring_policy.dart').read_text(encoding='utf-8')
for token in ['F9WiringPolicy', 'evaluateAndBuild', 'already', 'PhaseTag.none', 'append']:
    # The French duplicate message does not contain "already"; accept either explicit duplicate marker below.
    if token == 'already':
        if 'déjà reliées' not in wiring:
            errors.append('wiring-contract:duplicate-protection')
    elif token not in wiring:
        errors.append(f'wiring-contract:{token}')

panels = (ROOT / 'apps/electrosim/lib/f9_context_panels.dart').read_text(encoding='utf-8')
panels_compact = ''.join(panels.split())
for token in [
    'measurements-panel', 'eie-panel', 'student-diagnostic-panel',
    'properties-element-selector', 'properties-replace-element',
]:
    if token not in panels:
        errors.append(f'context-contract:{token}')
for token in [
    'role!=F9UserRole.student', "workspace!='Recherchededérangement'",
]:
    if token not in panels_compact:
        errors.append(f'context-contract:{token}')

visuals = (ROOT / 'apps/electrosim/lib/f9_component_visuals.dart').read_text(encoding='utf-8')
for token in ['F9CanvasVisualOverlay', 'F18ComponentAssetVisual', 'paintF18ComponentIdentity']:
    if token not in visuals:
        errors.append(f'visual-contract:{token}')

goldens = (ROOT / 'apps/electrosim/test/f9_goldens_test.dart').read_text(encoding='utf-8')
for token in ['390, 844', '820, 1180', '1440, 900', 'student troubleshooting diagnostic reference']:
    if token not in goldens:
        errors.append(f'golden-contract:{token}')

payload = {
    'phase': 'F9-FINAL',
    'status': 'PASS' if not errors else 'FAIL',
    'errors': errors,
}
print(json.dumps(payload, indent=2, ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
