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

# Historical F0 forbids scenario catalog content. On the convergence branch,
# F18 already contains V2 scenario contract fixtures, so the relevant
# invariant is stricter and more precise: no dependency on V1/legacy data.
scen = ROOT / 'packages/electrosim_scenarios'
convergence_mode = (ROOT / 'CONVERGENCE_VERSION').is_file()
if convergence_mode:
    policy = scen / 'REBUILD_POLICY.md'
    if not policy.is_file():
        errors.append('missing:packages/electrosim_scenarios/REBUILD_POLICY.md')
    forbidden_tokens = (
        'reference/legacy/',
        'electrosim-fieldfix',
        'fieldfix01',
        'exampleid',
        'example_id',
    )
    fixture_names = {'f10_examples.dart', 'f11_fault_scenarios.dart', 'f16_catalog.dart'}
    product_root = scen / 'lib'
    for p in scen.rglob('*'):
        if not p.is_file():
            continue
        rel = p.relative_to(ROOT).as_posix()
        # Dependency policy applies to shipped scenario code. Tests may
        # deliberately mention forbidden legacy keys to assert their absence
        # from serialized product payloads and must not be false positives.
        if p.suffix == '.dart' and product_root in p.parents:
            text = p.read_text(encoding='utf-8').lower()
            for token in forbidden_tokens:
                if token in text:
                    errors.append(f'legacy-scenario-dependency:{rel}:{token}')
        if p.name in fixture_names:
            first = p.read_text(encoding='utf-8').splitlines()[0] if p.read_text(encoding='utf-8') else ''
            if 'BOOTSTRAP_FIXTURE_ONLY' not in first:
                errors.append(f'unmarked-scenario-fixture:{rel}')
else:
    for p in scen.rglob('*'):
        if p.is_file() and p.name != 'README.md':
            errors.append(f'scenario-content-in-f0:{p.relative_to(ROOT).as_posix()}')

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
