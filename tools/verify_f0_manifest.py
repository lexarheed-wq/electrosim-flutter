#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
MAN=ROOT/"F0_MANIFEST.json"
errors=[]
try:
    data=json.loads(MAN.read_text(encoding="utf-8"))
except Exception as exc:
    print(json.dumps({"status":"FAIL","errors":[f"manifest-unreadable:{exc}"]},indent=2)); sys.exit(1)

def sha(path: Path) -> str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024), b""): h.update(chunk)
    return h.hexdigest()
if data.get("candidateVersion") != (ROOT/"VERSION").read_text().strip(): errors.append("manifest-version-mismatch")
entries=data.get("files")
if not isinstance(entries,list): errors.append("manifest-files-not-list"); entries=[]
for e in entries:
    rel=e.get("path")
    p=ROOT/rel if isinstance(rel,str) else None
    if not p or not p.is_file(): errors.append(f"manifest-missing-file:{rel}"); continue
    if p.stat().st_size != e.get("size_bytes"): errors.append(f"manifest-size-mismatch:{rel}")
    if sha(p) != e.get("sha256"): errors.append(f"manifest-hash-mismatch:{rel}")
if data.get("fileCount") != len(entries): errors.append("manifest-count-mismatch")
print(json.dumps({"status":"PASS" if not errors else "FAIL","errors":errors,"checked":len(entries)},indent=2,ensure_ascii=False))
sys.exit(0 if not errors else 1)
