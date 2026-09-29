#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FREEZE = ROOT / 'docs/f9/F8_CORE_FREEZE_FOR_F9.json'

def sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

data = json.loads(FREEZE.read_text(encoding='utf-8'))
errors: list[str] = []
for item in data['files']:
    path = ROOT / item['path']
    if not path.is_file():
        errors.append(f"missing:{item['path']}")
        continue
    actual = sha(path)
    if actual != item['sha256']:
        errors.append(f"changed:{item['path']}")

payload = {
    'phase': 'F9-FINAL',
    'check': 'F1-F8-core-freeze',
    'status': 'PASS' if not errors else 'FAIL',
    'checked': len(data['files']),
    'errors': errors,
}
print(json.dumps(payload, indent=2, ensure_ascii=False))
raise SystemExit(0 if not errors else 1)
