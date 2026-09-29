#!/usr/bin/env python3
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
ignore={'.DS_Store','F15_MANIFEST.json'}
files={}
for p in sorted(root.rglob('*')):
    if not p.is_file() or p.name in ignore or '.toolchain' in p.parts or '.dart_tool' in p.parts or 'build' in p.parts: continue
    rel=p.relative_to(root).as_posix(); files[rel]=hashlib.sha256(p.read_bytes()).hexdigest()
out={'schemaVersion':1,'phase':'F15-R5','status':'PASS','fileCount':len(files),'files':files}
(root/'F15_MANIFEST.json').write_text(json.dumps(out,indent=2,sort_keys=True)+'\n')
print(json.dumps({'phase':'F15-R5','status':'PASS','fileCount':len(files)},indent=2))
