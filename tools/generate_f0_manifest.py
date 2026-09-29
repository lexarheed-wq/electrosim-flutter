#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "F0_MANIFEST.json"

def excluded(rel: str) -> bool:
    return (
        rel == "F0_MANIFEST.json" or
        rel.startswith(".toolchain/") or
        rel.startswith("audit/") or
        "/__pycache__/" in f"/{rel}" or
        rel.endswith(".pyc") or
        rel.endswith(".DS_Store")
    )

def sha(path: Path) -> str:
    h=hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda:f.read(1024*1024), b""):
            h.update(chunk)
    return h.hexdigest()

files=[]
for p in sorted(ROOT.rglob("*")):
    if not p.is_file(): continue
    rel=p.relative_to(ROOT).as_posix()
    if excluded(rel): continue
    files.append({"path":rel,"size_bytes":p.stat().st_size,"sha256":sha(p)})
payload={
    "schemaVersion":2,
    "phase":"F0",
    "candidateVersion":(ROOT/"VERSION").read_text().strip(),
    "coverage":"all candidate source/data files except F0_MANIFEST.json, .toolchain/, audit/, Python caches and .DS_Store",
    "fileCount":len(files),
    "files":files,
}
OUT.write_text(json.dumps(payload,indent=2,ensure_ascii=False)+"\n",encoding="utf-8")
print(json.dumps({"status":"PASS","fileCount":len(files),"manifest":str(OUT)},indent=2))
