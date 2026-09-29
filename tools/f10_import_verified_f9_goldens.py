#!/usr/bin/env python3
from __future__ import annotations
import hashlib, json, os, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PARENT = ROOT.parent
TARGET_DIR = ROOT / 'apps/electrosim/test/goldens'
TARGET_APPROVAL = ROOT / 'docs/f9/F9_GOLDEN_APPROVAL.json'
EXPECTED = [
    'f9_compact_base.png', 'f9_compact_palette.png', 'f9_compact_properties.png',
    'f9_medium_base.png', 'f9_medium_palette.png', 'f9_medium_properties.png',
    'f9_expanded_base.png', 'f9_expanded_palette.png', 'f9_expanded_properties.png',
    'f9_compact_student_diagnostic.png',
]

def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open('rb') as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()

def verify(root: Path) -> tuple[bool, str]:
    approval = root / 'docs/f9/F9_GOLDEN_APPROVAL.json'
    golden_dir = root / 'apps/electrosim/test/goldens'
    if not approval.is_file():
        return False, 'approval-missing'
    try:
        data = json.loads(approval.read_text(encoding='utf-8'))
    except Exception as exc:
        return False, f'approval-unreadable:{exc}'
    if data.get('phase') != 'F9' or data.get('status') != 'APPROVED':
        return False, 'approval-not-approved'
    recorded = data.get('goldens')
    if not isinstance(recorded, dict) or set(recorded) != set(EXPECTED):
        return False, 'approval-file-set-mismatch'
    for name in EXPECTED:
        p = golden_dir / name
        if not p.is_file():
            return False, f'golden-missing:{name}'
        actual = sha256(p)
        if recorded.get(name) != actual:
            return False, f'golden-hash-mismatch:{name}'
    return True, 'verified'

def candidates() -> list[Path]:
    result: list[Path] = []
    env = os.environ.get('ELECTROSIM_F9_BASELINE')
    if env:
        result.append(Path(env).expanduser().resolve())
    preferred = PARENT / 'ElectroSim-Flutter-F9-FINAL-VENTURA-FIX10-CANDIDATE'
    result.append(preferred)
    for p in sorted(PARENT.glob('ElectroSim-Flutter-F9-*'), reverse=True):
        if p not in result:
            result.append(p)
    return result

# A verified local baseline is always preferred and avoids copying.
ok, reason = verify(ROOT)
if ok:
    print('F10_F9_GOLDENS_VERIFIED local')
    raise SystemExit(0)

errors: list[str] = []
for cand in candidates():
    if cand == ROOT or not cand.is_dir():
        continue
    ok, reason = verify(cand)
    if not ok:
        errors.append(f'{cand.name}:{reason}')
        continue
    TARGET_DIR.mkdir(parents=True, exist_ok=True)
    TARGET_APPROVAL.parent.mkdir(parents=True, exist_ok=True)
    for old in TARGET_DIR.glob('*.png'):
        old.unlink()
    for name in EXPECTED:
        shutil.copy2(cand / 'apps/electrosim/test/goldens' / name, TARGET_DIR / name)
    shutil.copy2(cand / 'docs/f9/F9_GOLDEN_APPROVAL.json', TARGET_APPROVAL)
    ok2, reason2 = verify(ROOT)
    if not ok2:
        raise SystemExit(f'F10_F9_GOLDENS_IMPORT_INTERNAL_FAIL {reason2}')
    print(f'F10_F9_GOLDENS_VERIFIED imported:{cand}')
    raise SystemExit(0)

print('F10_F9_GOLDENS_MISSING_OR_INVALID')
print('No sibling F9 baseline passed cryptographic verification against F9_GOLDEN_APPROVAL.json.')
if errors:
    print('Rejected candidates:')
    for e in errors[:20]:
        print(' -', e)
print('Keep the validated FIX10 folder beside this candidate, or set ELECTROSIM_F9_BASELINE to its path.')
raise SystemExit(1)
