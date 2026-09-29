#!/usr/bin/env python3
from __future__ import annotations
import csv, shutil, subprocess, sys, tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def run(root: Path):
    p=subprocess.run([sys.executable,str(root/'tools/f9_preflight_check.py')],cwd=root,text=True,capture_output=True)
    return p.returncode,p.stdout+p.stderr

def clone_to(td: str)->Path:
    clone=Path(td)/'candidate'
    shutil.copytree(ROOT,clone,ignore=shutil.ignore_patterns('.toolchain','audit','reference','__pycache__','*.pyc'))
    return clone

# Live candidate passes.
code,out=run(ROOT)
assert code==0 and '"status": "PASS"' in out, out

# Family registry cannot silently enable legacy import.
with tempfile.TemporaryDirectory() as td:
    clone=clone_to(td)
    p=clone/'docs/f9/F9_COMPONENT_FAMILY_MATRIX.csv'
    rows=list(csv.DictReader(p.open(encoding='utf-8')))
    rows[0]['automatic_import']='YES'
    with p.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
    code,out=run(clone)
    assert code!=0 and 'family-auto-import-must-remain-NO' in out, out

# Removing a core terminal role fails.
with tempfile.TemporaryDirectory() as td:
    clone=clone_to(td)
    p=clone/'docs/f9/F9_TERMINAL_ROLE_MATRIX.csv'
    rows=list(csv.DictReader(p.open(encoding='utf-8')))
    rows=[r for r in rows if r['terminal_role']!='pe']
    with p.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0].keys()); w.writeheader(); w.writerows(rows)
    code,out=run(clone)
    assert code!=0 and 'missing-core-terminal-role' in out, out

# Modifying production Dart during preparation-only work fails the freeze.
with tempfile.TemporaryDirectory() as td:
    clone=clone_to(td)
    target=next((clone/'packages').rglob('lib/*.dart'))
    target.write_text(target.read_text(encoding='utf-8')+'\n// illicit preparation-only mutation\n',encoding='utf-8')
    code,out=run(clone)
    assert code!=0 and 'f8-production-freeze-failed' in out, out

print('F9_R10_PREFLIGHT_TEST_PASS')
