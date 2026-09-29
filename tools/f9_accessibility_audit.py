#!/usr/bin/env python3
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []
main = (ROOT / 'apps/electrosim/lib/main.dart').read_text(encoding='utf-8')
palette = (ROOT / 'apps/electrosim/lib/f9_component_palette.dart').read_text(encoding='utf-8')
panels = (ROOT / 'apps/electrosim/lib/f9_context_panels.dart').read_text(encoding='utf-8')
shell = (ROOT / 'packages/electrosim_ui_kit/lib/src/workspace_shell.dart').read_text(encoding='utf-8')
tokens = (ROOT / 'packages/electrosim_ui_kit/lib/src/design_tokens.dart').read_text(encoding='utf-8')

checks = {
    'home-semantics': 'Semantics(' in main and 'button: true' in main,
    'palette-semantics': 'Semantics(' in palette and 'button: true' in palette,
    'live-status': 'liveRegion: true' in main and 'liveRegion: true' in panels,
    'escape-shortcut': 'LogicalKeyboardKey.escape' in main,
    'keyboard-selection': 'properties-element-selector' in panels,
    'context-alternative': 'properties-replace-element' in panels and 'properties-delete-element' in panels,
    'minimum-touch-target': 'minimumTouchTarget = 48' in tokens and 'minimumTouchTarget' in shell,
    'compact-overlay': '_buildCompact()' in shell and 'Positioned.fill' in shell,
    'diagnostic-role-rule': 'F9UserRole.student' in panels and "Recherche de dérangement" in panels,
}
for name, ok in checks.items():
    if not ok:
        errors.append(name)

print(json.dumps({
    'phase': 'F9-FINAL',
    'audit': 'accessibility-input-static',
    'status': 'PASS' if not errors else 'FAIL',
    'checks': checks,
    'errors': errors,
}, indent=2, ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
