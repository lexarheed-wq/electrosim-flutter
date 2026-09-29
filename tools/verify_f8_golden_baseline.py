#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GOLDEN_DIR = ROOT / 'packages/electrosim_canvas/test/goldens'
BASELINE = ROOT / 'docs/f8/F8_GOLDEN_BASELINE.json'
EXPECTED = {'canvas_compact.png', 'canvas_medium.png', 'canvas_expanded.png'}

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

errors = []
if not BASELINE.is_file():
    errors.append('baseline-not-approved')
    data = {}
else:
    try:
        data = json.loads(BASELINE.read_text(encoding='utf-8'))
    except Exception as exc:
        errors.append(f'baseline-unreadable:{exc}')
        data = {}
if data.get('phase') not in (None, 'F8'):
    errors.append('baseline-phase-mismatch')
if data.get('status') not in (None, 'APPROVED'):
    errors.append('baseline-not-approved-status')
entries = data.get('goldens') if isinstance(data.get('goldens'), list) else []
seen = set()
for entry in entries:
    name = entry.get('file') if isinstance(entry, dict) else None
    if not isinstance(name, str):
        errors.append('baseline-entry-invalid')
        continue
    seen.add(name)
    p = GOLDEN_DIR / name
    if not p.is_file():
        errors.append(f'golden-missing:{name}')
        continue
    if p.stat().st_size != entry.get('sizeBytes'):
        errors.append(f'golden-size-mismatch:{name}')
    if sha256(p) != entry.get('sha256'):
        errors.append(f'golden-hash-mismatch:{name}')
if seen != EXPECTED:
    errors.append(f'baseline-file-set-mismatch:{sorted(seen)}')

payload = {'phase':'F8','status':'PASS' if not errors else 'FAIL','baselineApproved':not errors,'errors':errors}
print(json.dumps(payload, indent=2, ensure_ascii=False))
sys.exit(0 if not errors else 1)
