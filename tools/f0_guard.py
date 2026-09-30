#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, sys

ROOT = Path(__file__).resolve().parents[1]
errors = []

required = [
    'apps/electrosim/pubspec.yaml',
    'apps/electrosim/lib/main.dart',
    'apps/electrosim/test/f0_smoke_test.dart',
    'reference/REFERENCE_BASELINE.json',
    'docs/f0/MIGRATION_MATRIX.csv',
    'docs/f0/legacy_component_inventory.csv',
]
for rel in required:
    if not (ROOT / rel).is_file():
        errors.append(f'missing:{rel}')

# F0 invariant: no JS/TS implementation from the historical application may be
# introduced into project-authored source.  Deliberately scan only authored
# roots. External/generated SDK and build directories (notably .toolchain/)
# are dependencies, not ElectroSim source, and must never trigger this rule.
authored_roots = [
    ROOT / 'apps',
    ROOT / 'packages',
    ROOT / 'tools',
    ROOT / 'integration_test',
    ROOT / 'ci',
]
ignored_dir_names = {'.dart_tool', 'build', 'Pods', 'ephemeral', '__pycache__'}
scanned_files = 0
for source_root in authored_roots:
    if not source_root.exists():
        continue
    for p in source_root.rglob('*'):
        if not p.is_file():
            continue
        rel = p.relative_to(ROOT)
        if any(part in ignored_dir_names for part in rel.parts):
            continue
        scanned_files += 1
        if p.suffix.lower() in {'.js', '.ts'}:
            errors.append(f'legacy-code-outside-reference:{rel.as_posix()}')

# Post-F0 Dart packages are legitimate regression inputs. The guard keeps
# enforcing the timeless invariant above (no authored legacy JS/TS) rather
# than preserving temporary "package must still be empty" assumptions from F0.

# Verify frozen ZIP hash. The distributable must be self-contained: a missing
# immutable legacy oracle is a structured gate failure, never an uncaught
# FileNotFoundError.
meta = json.loads((ROOT / 'reference/REFERENCE_BASELINE.json').read_text())
zip_path = ROOT / 'reference/legacy/ElectroSim-FIELDFIX01-R1.zip'
if not zip_path.is_file():
    errors.append('missing:reference/legacy/ElectroSim-FIELDFIX01-R1.zip')
else:
    h = hashlib.sha256(zip_path.read_bytes()).hexdigest()
    if h != meta['legacy_zip']['sha256']:
        errors.append('legacy-reference-hash-mismatch')

# Validate test vector IDs unique and JSON parseable.
ids = []
for p in (ROOT / 'test_vectors').rglob('*.json'):
    data = json.loads(p.read_text())
    if 'id' in data:
        ids.append(data['id'])
if len(ids) != len(set(ids)):
    errors.append('duplicate-test-vector-id')

result = {
    'status': 'PASS' if not errors else 'FAIL',
    'errors': errors,
    'vector_count': len(ids),
    'authored_files_scanned': scanned_files,
    'excluded_external_roots': ['.toolchain/', '.git/', 'audit/', 'reference/legacy/', 'docs/source/'],
}
print(json.dumps(result, indent=2, ensure_ascii=False))
sys.exit(0 if not errors else 1)
