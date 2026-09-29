#!/usr/bin/env python3
from pathlib import Path
import sys,json,re
root=Path(__file__).resolve().parents[1]
checks=[]
def check(name, ok): checks.append((name,bool(ok)))
package=root/'packages/electrosim_storage'
check('storage-package', (package/'pubspec.yaml').is_file())
models=(package/'lib/src/storage_models.dart').read_text(encoding='utf-8')
repo=(package/'lib/src/local_storage_repository.dart').read_text(encoding='utf-8')
exports=(package/'lib/src/export_service.dart').read_text(encoding='utf-8')
tests=(package/'test/storage_repository_test.dart').read_text(encoding='utf-8')
check('schema-version', 'currentSchemaVersion = 1' in models and "schemaVersion" in models)
check('explicit-migration', '_migrateV0' in models and 'Unsupported saved circuit schemaVersion' in models)
check('atomic-write', '.tmp' in repo and '.bak' in repo and 'rename' in repo)
check('recovery', '_recoverBackups' in repo and '_removeAbandonedTemps' in repo)
check('multiple-saves', 'listSaves' in repo and 'open(String saveId)' in repo)
check('explicit-open-not-last', 'open(String saveId)' in repo and 'last' not in re.sub(r'last[A-Za-z]*', '', repo))
check('safe-save-id', 'Unsafe save identifier' in repo and 'RegExp' in repo)
check('json-import-export', 'exportJson' in repo and 'importJson' in repo)
check('csv-export', 'toCsv' in exports)
check('pdf-export', 'toPdf' in exports and '%PDF-1.4' in exports)
check('roundtrip-test', 'round-trip preserves circuit and metadata' in tests)
check('recovery-test', 'recovers a valid backup' in tests)
check('interrupted-temp-test', 'removes abandoned temp files' in tests)
check('no-storage-ui-dependency', 'flutter' not in (package/'pubspec.yaml').read_text(encoding='utf-8').lower())
check('no-catalog-mutation', 'ExampleRepository' not in repo and 'FaultScenario' not in repo)
errors=[name for name,ok in checks if not ok]
print(json.dumps({'phase':'F14-R1','status':'PASS' if not errors else 'FAIL','checks':len(checks),'errors':errors},indent=2))
if errors: sys.exit(1)
print(f'F14_STATIC_CONTRACT_PASS {len(checks)}/{len(checks)}')
