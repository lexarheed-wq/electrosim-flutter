#!/usr/bin/env python3
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
exclude_prefixes=('.toolchain/','.dart_tool/','build/','audit/runtime/')
files={}
for p in sorted(root.rglob('*')):
    if not p.is_file(): continue
    rel=p.relative_to(root).as_posix()
    if rel=='F10_MANIFEST.json' or any(rel.startswith(x) for x in exclude_prefixes): continue
    files[rel]=hashlib.sha256(p.read_bytes()).hexdigest()
(root/'F10_MANIFEST.json').write_text(json.dumps({
    'schemaVersion':1,
    'phase':'F10-R3',
    'status':'CANDIDATE',
    'fileCount':len(files),
    'files':files,
},indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps({'phase':'F10-R3','status':'PASS','fileCount':len(files)},indent=2))
