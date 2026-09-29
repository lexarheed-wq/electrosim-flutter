#!/usr/bin/env python3
from __future__ import annotations
import hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; MAN=ROOT/'F7_MANIFEST.json'; errors=[]
def sha(p:Path)->str:
    h=hashlib.sha256()
    with p.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
    return h.hexdigest()
try: data=json.loads(MAN.read_text(encoding='utf-8'))
except Exception as e:
    print(json.dumps({'phase':'F7','status':'FAIL','errors':[f'manifest-unreadable:{e}']},indent=2)); sys.exit(1)
if data.get('phase')!='F7': errors.append('manifest-phase-mismatch')
if data.get('candidateVersion')!=(ROOT/'VERSION').read_text().strip(): errors.append('manifest-version-mismatch')
entries=data.get('files') if isinstance(data.get('files'),list) else []
if data.get('fileCount')!=len(entries): errors.append('manifest-count-mismatch')
for e in entries:
    rel=e.get('path'); p=ROOT/rel if isinstance(rel,str) else None
    if not p or not p.is_file(): errors.append(f'missing:{rel}'); continue
    if p.stat().st_size!=e.get('size_bytes'): errors.append(f'size:{rel}')
    if sha(p)!=e.get('sha256'): errors.append(f'hash:{rel}')
print(json.dumps({'phase':'F7','status':'PASS' if not errors else 'FAIL','checked':len(entries),'errors':errors},indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
