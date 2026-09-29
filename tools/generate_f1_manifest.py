#!/usr/bin/env python3
from __future__ import annotations
import hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'F1_MANIFEST.json'
def excluded(rel:str)->bool:
    return (
      rel in {'F0_MANIFEST.json','F1_MANIFEST.json','F2_MANIFEST.json'} or rel.startswith('.toolchain/') or rel.startswith('audit/') or
      rel.startswith('reference/legacy/') or rel.startswith('docs/source/') or
      '/__pycache__/' in f'/{rel}' or '/.dart_tool/' in f'/{rel}' or '/build/' in f'/{rel}' or
      '/coverage/' in f'/{rel}' or rel.endswith('/pubspec.lock') or rel.endswith('.pyc') or rel.endswith('.DS_Store')
    )
def sha(p:Path)->str:
    h=hashlib.sha256()
    with p.open('rb') as f:
        for c in iter(lambda:f.read(1024*1024),b''): h.update(c)
    return h.hexdigest()
files=[]
for p in sorted(ROOT.rglob('*')):
    if not p.is_file(): continue
    rel=p.relative_to(ROOT).as_posix()
    if excluded(rel): continue
    files.append({'path':rel,'size_bytes':p.stat().st_size,'sha256':sha(p)})
payload={'schemaVersion':1,'phase':'F1','candidateVersion':(ROOT/'VERSION').read_text().strip(),'fileCount':len(files),'files':files}
OUT.write_text(json.dumps(payload,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps({'status':'PASS','fileCount':len(files)},indent=2))
