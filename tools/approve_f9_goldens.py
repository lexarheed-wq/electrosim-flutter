#!/usr/bin/env python3
from __future__ import annotations
import argparse, hashlib, json
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GOLDEN_DIR = ROOT / 'apps/electrosim/test/goldens'
APPROVAL = ROOT / 'docs/f9/F9_GOLDEN_APPROVAL.json'
EXPECTED = [
    'f9_compact_base.png', 'f9_compact_palette.png', 'f9_compact_properties.png',
    'f9_medium_base.png', 'f9_medium_palette.png', 'f9_medium_properties.png',
    'f9_expanded_base.png', 'f9_expanded_palette.png', 'f9_expanded_properties.png',
    'f9_compact_student_diagnostic.png',
]

def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def current():
    missing = [name for name in EXPECTED if not (GOLDEN_DIR / name).is_file()]
    if missing:
        raise SystemExit('Missing F9 goldens: ' + ', '.join(missing))
    return {name: digest(GOLDEN_DIR / name) for name in EXPECTED}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--approve', action='store_true')
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    hashes = current()
    if args.approve:
        APPROVAL.parent.mkdir(parents=True, exist_ok=True)
        APPROVAL.write_text(json.dumps({
            'phase': 'F9',
            'status': 'APPROVED',
            'approvedAt': datetime.now(timezone.utc).isoformat(),
            'goldens': hashes,
        }, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
        print('F9_GOLDENS_APPROVED')
        return
    if args.verify:
        if not APPROVAL.is_file():
            raise SystemExit('F9 golden approval is missing.')
        data = json.loads(APPROVAL.read_text(encoding='utf-8'))
        if data.get('status') != 'APPROVED' or data.get('goldens') != hashes:
            raise SystemExit('F9 golden approval does not match current PNG files.')
        print('F9_GOLDENS_VERIFIED')
        return
    parser.error('Use --approve or --verify')

if __name__ == '__main__':
    main()
