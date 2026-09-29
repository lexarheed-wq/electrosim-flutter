#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
PATH=ROOT/'F9_MANIFEST.json'
def sha(p:Path)->str:
    h=hashlib.sha256()
    with p.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
    return h.hexdigest()
data=json.loads(PATH.read_text(encoding='utf-8')); errors=[]
for item in data['files']:
    p=ROOT/item['path']
    if not p.is_file(): errors.append(f"missing:{item['path']}")
    elif p.stat().st_size != item['size_bytes']: errors.append(f"size:{item['path']}")
    elif sha(p) != item['sha256']: errors.append(f"sha256:{item['path']}")
print(json.dumps({'phase':'F9-FINAL','status':'PASS' if not errors else 'FAIL','checked':len(data['files']),'errors':errors},indent=2,ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
