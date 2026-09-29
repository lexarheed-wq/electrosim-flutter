#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'F10_R3_BASELINE_MANIFEST.json').read_text(encoding='utf-8'))
allowed={
    'VERSION','README.md','validate.sh','F10_MANIFEST.json','F11_MANIFEST.json',
    'packages/electrosim_scenarios/lib/electrosim_scenarios.dart',
}
allowed_prefixes=('docs/f11/','tools/f11_','tools/bootstrap_flutter_and_run_f11.sh','tools/run_f11_gate.sh','packages/electrosim_scenarios/lib/src/fault_','packages/electrosim_scenarios/lib/src/f11_','packages/electrosim_scenarios/test/fault_','packages/electrosim_scenarios/tool/validate_fault_')
errors=[]
checked=0
for rel,expected in manifest['files'].items():
    if rel in allowed or any(rel.startswith(p) for p in allowed_prefixes):
        continue
    p=root/rel
    if not p.is_file():
        errors.append(f'missing:{rel}')
        continue
    checked+=1
    actual=hashlib.sha256(p.read_bytes()).hexdigest()
    if actual!=expected:
        errors.append(f'changed:{rel}')
print(json.dumps({'phase':'F11-R1','baseline':'F10-R3','status':'PASS' if not errors else 'FAIL','checked':checked,'errors':errors},indent=2))
if errors: sys.exit(1)
print('F11_F10_FREEZE_PASS')
