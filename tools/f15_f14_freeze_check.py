#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'F14_R1_BASELINE_MANIFEST.json').read_text(encoding='utf-8'))
allowed={'VERSION','README.md','validate.sh','F14_MANIFEST.json','F15_MANIFEST.json','F14_R1_BASELINE_MANIFEST.json'}
allowed_prefixes=('docs/f15/','distribution/f15/','tools/f15_','tools/bootstrap_flutter_and_run_f15.sh','tools/run_f15_gate.sh','README_F15_')
errors=[]; checked=0
for rel,expected in m['files'].items():
    if rel in allowed or any(rel.startswith(p) for p in allowed_prefixes):
        continue
    p=root/rel
    if not p.is_file(): errors.append(f'missing:{rel}'); continue
    checked+=1
    if hashlib.sha256(p.read_bytes()).hexdigest()!=expected: errors.append(f'changed:{rel}')
print(json.dumps({'phase':'F15-R1','baseline':'F14-R1','status':'PASS' if not errors else 'FAIL','checked':checked,'errors':errors},indent=2))
if errors: sys.exit(1)
print('F15_F14_FREEZE_PASS')
