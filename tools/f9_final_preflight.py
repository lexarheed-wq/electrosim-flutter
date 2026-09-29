#!/usr/bin/env python3
from __future__ import annotations
import re, shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def run(script: str, root: Path = ROOT):
    p = subprocess.run([sys.executable, str(root / 'tools' / script)], cwd=root, text=True, capture_output=True)
    return p.returncode, p.stdout + p.stderr

version = (ROOT / 'VERSION').read_text(encoding='utf-8').strip()
assert re.fullmatch(r'F9-FINAL-VENTURA(?:-FIX[1-9]\d*)?-CANDIDATE', version), version
for script in ['f9_f8_core_freeze_check.py', 'f9_architecture_guard.py', 'f9_static_contract_check.py', 'f9_accessibility_audit.py']:
    code, out = run(script)
    assert code == 0 and 'PASS' in out, (script, out)

for rel in [
    'apps/electrosim/lib/f9_wiring_policy.dart',
    'apps/electrosim/lib/f9_component_visuals.dart',
    'apps/electrosim/lib/f9_context_panels.dart',
    'apps/electrosim/test/f9_wiring_policy_test.dart',
    'apps/electrosim/test/f9_goldens_test.dart',
    'docs/f9/F9_FINAL_REPORT.md',
]:
    assert (ROOT / rel).is_file(), rel

with tempfile.TemporaryDirectory() as td:
    clone = Path(td) / 'candidate'
    shutil.copytree(ROOT, clone, ignore=shutil.ignore_patterns('.toolchain', 'audit', '__pycache__', '*.pyc', '.dart_tool', 'build', 'coverage'))
    target = clone / 'packages/electrosim_canvas/lib/src/circuit_visual_layout.dart'
    target.write_text(target.read_text(encoding='utf-8') + '\n// illicit F8 mutation\n', encoding='utf-8')
    code, out = run('f9_f8_core_freeze_check.py', clone)
    assert code != 0 and 'changed:' in out, out

print('F9_FINAL_PREFLIGHT_PASS')
