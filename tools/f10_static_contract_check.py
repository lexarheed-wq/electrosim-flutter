#!/usr/bin/env python3
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
pkg = root / 'packages' / 'electrosim_scenarios'
checks = []

def ok(name, cond):
    checks.append((name, bool(cond)))

files = [p for p in pkg.rglob('*') if p.is_file()]
text = '\n'.join(p.read_text(encoding='utf-8', errors='ignore') for p in files)
pubspec = (pkg / 'pubspec.yaml').read_text(encoding='utf-8')
ok('package implemented', (pkg / 'lib/electrosim_scenarios.dart').exists())
ok('ExampleRepository present', 'class ExampleRepository' in text)
ok('ExampleValidator present', 'class ExampleValidator' in text)
examples_text = (pkg / 'lib/src/f10_examples.dart').read_text(encoding='utf-8')
ok('exactly small initial corpus', examples_text.count("ExampleId('EX-DC-") == 3)
ok('validation stamp present', 'ExampleValidationStamp' in text)
ok('no FaultScenario symbol', 'FaultScenario' not in text)
ok('no fault package dependency', 'fault' not in '\n'.join(line.lower() for line in pubspec.splitlines() if 'path:' in line or line.strip().endswith(':')))
ok('F10 tool present', (pkg / 'tool/validate_examples.dart').exists())
ok('verified F9 golden importer present', (root / 'tools/f10_import_verified_f9_goldens.py').exists())
imp = (root / 'tools/f10_import_verified_f9_goldens.py').read_text(encoding='utf-8')
ok('F9 golden importer checks approval hashes', all(token in imp for token in ['F9_GOLDEN_APPROVAL.json', 'golden-hash-mismatch', 'status', 'APPROVED', 'sha256']))
ok('F9 golden importer prefers FIX10', 'F9-FINAL-VENTURA-FIX10-CANDIDATE' in imp)
failed = [name for name, passed in checks if not passed]
for name, passed in checks:
    print(f"{'PASS' if passed else 'FAIL'} {name}")
if failed:
    print('F10_STATIC_CONTRACT_FAIL', ', '.join(failed))
    sys.exit(1)
print(f'F10_STATIC_CONTRACT_PASS {len(checks)}/{len(checks)}')
