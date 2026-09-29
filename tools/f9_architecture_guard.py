#!/usr/bin/env python3
from __future__ import annotations
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TARGETS = [ROOT / 'packages/electrosim_ui_kit/lib', ROOT / 'apps/electrosim/lib']
FORBIDDEN_IMPORTS = (
    'electrosim_solver_dc',
    'electrosim_solver_ac',
    'electrosim_topology',
    'electrosim_measurements',
    'electrosim_energy',
    'electrosim_pv',
)
UI_KIT_FORBIDDEN = ('electrosim_domain', 'electrosim_canvas')
FORBIDDEN_CALL_PATTERNS = (
    re.compile(r'\bSolver[A-Za-z0-9_]*\s*\('),
    re.compile(r'\bsolve\s*\('),
    re.compile(r'\bTopologyEngine\b'),
    re.compile(r'\bMeasurementEngine\b'),
    re.compile(r'\bEnergyEngine\b'),
)

errors: list[str] = []
checked = 0
for base in TARGETS:
    for path in sorted(base.rglob('*.dart')):
        checked += 1
        rel = path.relative_to(ROOT).as_posix()
        text = path.read_text(encoding='utf-8')
        for name in FORBIDDEN_IMPORTS:
            if f'package:{name}/' in text:
                errors.append(f'{rel}: forbidden engine import {name}')
        if rel.startswith('packages/electrosim_ui_kit/'):
            for name in UI_KIT_FORBIDDEN:
                if f'package:{name}/' in text:
                    errors.append(f'{rel}: ui-kit must not depend on {name}')
        for pattern in FORBIDDEN_CALL_PATTERNS:
            if pattern.search(text):
                errors.append(f'{rel}: forbidden electrical computation pattern {pattern.pattern}')

main = (ROOT / 'apps/electrosim/lib/main.dart').read_text(encoding='utf-8')
if 'CircuitState(' not in main or 'SimulatorCanvas(' not in main:
    errors.append('apps/electrosim/lib/main.dart: F8 CircuitState/SimulatorCanvas integration missing')
if 'electrosim_ui_kit' not in main:
    errors.append('apps/electrosim/lib/main.dart: F9 UI kit not integrated')

payload = {'phase':'F9-FINAL','status':'PASS' if not errors else 'FAIL','checkedDartFiles':checked,'errors':errors}
print(json.dumps(payload, indent=2, ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
