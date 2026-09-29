#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'F11_R1_BASELINE_MANIFEST.json').read_text(encoding='utf-8'))
allowed={'VERSION','README.md','validate.sh','F11_MANIFEST.json','F12_MANIFEST.json'}
allowed_prefixes=('docs/f12/','tools/f12_','tools/bootstrap_flutter_and_run_f12.sh','tools/run_f12_gate.sh','packages/electrosim_tp/')
errors=[]; checked=0
for rel,expected in m['files'].items():
    if rel in allowed or any(rel.startswith(p) for p in allowed_prefixes): continue
    p=root/rel
    if not p.is_file(): errors.append(f'missing:{rel}'); continue
    checked+=1
    if hashlib.sha256(p.read_bytes()).hexdigest()!=expected: errors.append(f'changed:{rel}')
print(json.dumps({'phase':'F12-R2','baseline':'F11-R1','status':'PASS' if not errors else 'FAIL','checked':checked,'errors':errors},indent=2))
if errors: sys.exit(1)
print('F12_F11_FREEZE_PASS')
