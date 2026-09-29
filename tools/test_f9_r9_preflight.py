#!/usr/bin/env python3
from __future__ import annotations
import subprocess, sys, tempfile, shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def run(root: Path):
    p=subprocess.run([sys.executable,str(root/'tools/f9_preflight_check.py')],cwd=root,text=True,capture_output=True)
    return p.returncode,p.stdout+p.stderr

code,out=run(ROOT)
assert code==0 and '"status": "PASS"' in out, out
# Safety check: a Dart production file in the still-closed UI kit must fail.
with tempfile.TemporaryDirectory() as td:
    clone=Path(td)/'candidate'
    shutil.copytree(ROOT,clone,ignore=shutil.ignore_patterns('.toolchain','audit','reference','__pycache__','*.pyc'))
    bad=clone/'packages/electrosim_ui_kit/lib'
    bad.mkdir(parents=True,exist_ok=True)
    (bad/'premature.dart').write_text('void x() {}\n')
    code,out=run(clone)
    assert code!=0 and 'f9-opened-prematurely' in out, out
print('F9_R9_PREFLIGHT_TEST_PASS')
