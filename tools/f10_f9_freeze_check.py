#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
manifest=json.loads((root/'F9_OFFICIAL_BASELINE_MANIFEST.json').read_text(encoding='utf-8'))
allowed=(
    'VERSION',
    'packages/electrosim_scenarios/',
    'docs/f10/',
    'README_F10_R1.md',
    'tools/f10_',
    'validate_f10.sh',
    'F9_OFFICIAL_BASELINE_MANIFEST.json',
    'F10_MANIFEST.json',
)
errors=[]
for rel, expected in manifest['files'].items():
    if rel in {'VERSION','validate.sh'} or rel.startswith('packages/electrosim_scenarios/'):
        continue
    p=root/rel
    if not p.is_file():
        errors.append(f'missing:{rel}'); continue
    actual=hashlib.sha256(p.read_bytes()).hexdigest()
    if actual!=expected: errors.append(f'changed:{rel}')
if errors:
    print('F10_F9_FREEZE_FAIL')
    print('\n'.join(errors[:40]))
    sys.exit(1)
print('F10_F9_FREEZE_PASS')
