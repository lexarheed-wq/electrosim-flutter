#!/usr/bin/env python3
from __future__ import annotations
import shutil, subprocess, sys, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def run(root: Path, script: str):
    p = subprocess.run([sys.executable, str(root / 'tools' / script)], cwd=root, text=True, capture_output=True)
    return p.returncode, p.stdout + p.stderr

def clone_to(td: str) -> Path:
    clone = Path(td) / 'candidate'
    shutil.copytree(
        ROOT,
        clone,
        ignore=shutil.ignore_patterns('.toolchain', 'audit', '__pycache__', '*.pyc', '.dart_tool', 'build', 'coverage'),
    )
    return clone

assert (ROOT / 'VERSION').read_text(encoding='utf-8').strip() == 'F9-R13-VENTURA-CANDIDATE'
code, out = run(ROOT, 'f9_f8_core_freeze_check.py')
assert code == 0 and '"status": "PASS"' in out, out
code, out = run(ROOT, 'f9_static_contract_check.py')
assert code == 0 and '"status": "PASS"' in out, out

for rel in [
    'apps/electrosim/lib/f9_element_editor.dart',
    'apps/electrosim/test/f9_element_editor_test.dart',
    'docs/f9/F9_R13_REPORT.md',
]:
    assert (ROOT / rel).is_file(), rel

with tempfile.TemporaryDirectory() as td:
    clone = clone_to(td)
    (clone / 'apps/electrosim/lib/f9_element_editor.dart').unlink()
    code, out = run(clone, 'f9_static_contract_check.py')
    assert code != 0 and 'f9_element_editor.dart' in out, out

with tempfile.TemporaryDirectory() as td:
    clone = clone_to(td)
    target = clone / 'packages/electrosim_canvas/lib/src/circuit_visual_layout.dart'
    target.write_text(target.read_text(encoding='utf-8') + '\n// illicit F8 mutation\n', encoding='utf-8')
    code, out = run(clone, 'f9_f8_core_freeze_check.py')
    assert code != 0 and 'changed:' in out, out

print('F9_R13_PREFLIGHT_TEST_PASS')
