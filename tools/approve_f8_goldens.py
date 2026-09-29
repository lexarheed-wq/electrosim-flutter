#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json, sys
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GOLDEN_DIR = ROOT / 'packages/electrosim_canvas/test/goldens'
OUT = ROOT / 'docs/f8/F8_GOLDEN_BASELINE.json'
NAMES = ('canvas_compact.png', 'canvas_medium.png', 'canvas_expanded.png')

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

parser = argparse.ArgumentParser(description='Approve the current F8 golden images after human visual review.')
parser.add_argument('--approve', action='store_true', help='Required explicit approval flag.')
args = parser.parse_args()
if not args.approve:
    print('Refusing to approve goldens without explicit --approve.', file=sys.stderr)
    print('Review the three PNG files first, then run: python3 tools/approve_f8_goldens.py --approve', file=sys.stderr)
    sys.exit(2)

missing = [name for name in NAMES if not (GOLDEN_DIR / name).is_file()]
if missing:
    print(json.dumps({'phase':'F8','status':'FAIL','errors':[f'missing:{n}' for n in missing]}, indent=2))
    sys.exit(1)

entries = []
for name in NAMES:
    p = GOLDEN_DIR / name
    entries.append({'file': name, 'sizeBytes': p.stat().st_size, 'sha256': sha256(p)})

payload = {
    'schemaVersion': 1,
    'phase': 'F8',
    'status': 'APPROVED',
    'approvedAt': datetime.now(timezone.utc).isoformat(),
    'note': 'Human-reviewed visual baseline for F8 compact/medium/expanded profiles.',
    'goldens': entries,
}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print(json.dumps({'phase':'F8','status':'APPROVED','baseline':str(OUT.relative_to(ROOT)),'goldens':entries}, indent=2, ensure_ascii=False))
