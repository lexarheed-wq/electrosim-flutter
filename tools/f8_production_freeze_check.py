#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
FREEZE=ROOT/'docs/f9/F8_PRODUCTION_FREEZE_R10.json'
errors=[]
if not FREEZE.is_file():
    print(json.dumps({'phase':'F8-PRODUCTION-FREEZE','status':'FAIL','errors':['missing-freeze-file']},indent=2))
    sys.exit(1)
ref=json.loads(FREEZE.read_text(encoding='utf-8'))
files=[]
for base in [ROOT/'apps',ROOT/'packages']:
    if not base.exists():
        continue
    for p in sorted(base.rglob('*.dart')):
        pos=p.as_posix()
        if '/test/' in pos or '/example/' in pos:
            continue
        rel=p.relative_to(ROOT).as_posix()
        digest=hashlib.sha256(p.read_bytes()).hexdigest()
        files.append({'path':rel,'sha256':digest,'size_bytes':p.stat().st_size})
h=hashlib.sha256()
for r in files:
    h.update(r['path'].encode()); h.update(b'\0'); h.update(r['sha256'].encode()); h.update(b'\n')
tree=h.hexdigest()
if len(files)!=ref.get('dartProductionFileCount'):
    errors.append(f"file-count:{len(files)}!={ref.get('dartProductionFileCount')}")
if tree!=ref.get('treeSha256'):
    errors.append('tree-sha256-mismatch')
ref_by={r['path']:r for r in ref.get('files',[])}
cur_by={r['path']:r for r in files}
for p in sorted(set(ref_by)|set(cur_by)):
    if p not in ref_by: errors.append('added:'+p)
    elif p not in cur_by: errors.append('removed:'+p)
    elif ref_by[p]['sha256']!=cur_by[p]['sha256']: errors.append('changed:'+p)
status='PASS' if not errors else 'FAIL'
print(json.dumps({'phase':'F8-PRODUCTION-FREEZE','status':status,'dartProductionFileCount':len(files),'treeSha256':tree,'errors':errors},indent=2,ensure_ascii=False))
sys.exit(0 if not errors else 1)
