#!/usr/bin/env python3
from pathlib import Path
import hashlib,json,sys
root=Path(__file__).resolve().parents[1]
m=json.loads((root/'F10_MANIFEST.json').read_text(encoding='utf-8'))
errors=[]
for rel,expected in m['files'].items():
    p=root/rel
    if not p.is_file(): errors.append(f'missing:{rel}'); continue
    actual=hashlib.sha256(p.read_bytes()).hexdigest()
    if actual!=expected: errors.append(f'changed:{rel}')
print(json.dumps({'phase':'F10-R3','status':'PASS' if not errors else 'FAIL','checked':len(m['files']),'errors':errors},indent=2))
if errors: sys.exit(1)
