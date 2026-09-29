#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'F12_R3_BASELINE_MANIFEST.json').read_text(encoding='utf-8'))
allowed={'VERSION','README.md','validate.sh','F12_MANIFEST.json','F13_MANIFEST.json'}
allowed_prefixes=('docs/f13/','tools/f13_','tools/bootstrap_flutter_and_run_f13.sh','tools/run_f13_gate.sh','packages/electrosim_diagnostics/','README_F13_')
errors=[]; checked=0
for rel,expected in m['files'].items():
    if rel in allowed or any(rel.startswith(p) for p in allowed_prefixes): continue
    p=root/rel
    if not p.is_file(): errors.append(f'missing:{rel}'); continue
    checked+=1
    if hashlib.sha256(p.read_bytes()).hexdigest()!=expected: errors.append(f'changed:{rel}')
print(json.dumps({'phase':'F13-R1','baseline':'F12-R3','status':'PASS' if not errors else 'FAIL','checked':checked,'errors':errors},indent=2))
if errors: sys.exit(1)
print('F13_F12_FREEZE_PASS')
