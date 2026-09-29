#!/usr/bin/env python3
from pathlib import Path
import json,sys
root=Path(__file__).resolve().parents[1]
p=root/'packages/electrosim_storage'
repo=(p/'lib/src/local_storage_repository.dart').read_text(encoding='utf-8')
models=(p/'lib/src/storage_models.dart').read_text(encoding='utf-8')
checks={
 'user-saves-distinct': 'ExampleRepository' not in repo and 'FaultScenarioRepository' not in repo,
 'transaction-temp-first': repo.find('writeAsString') < repo.find('rename(target.path)'),
 'validate-before-replace': repo.find('fromJsonString(await temp.readAsString())') < repo.find('target.rename(backup.path)'),
 'backup-rollback': 'backup.rename(target.path)' in repo,
 'schema-version-persisted': "'schemaVersion': currentSchemaVersion" in models,
 'engine-version-persisted': "'engineVersion': engineVersion" in models,
 'circuit-revision-persisted': "'circuit': circuit.toJson()" in models,
}
errors=[k for k,v in checks.items() if not v]
print(json.dumps({'phase':'F14-R1','status':'PASS' if not errors else 'FAIL','checks':checks,'errors':errors},indent=2))
if errors: sys.exit(1)
print(f'F14_STORAGE_STATIC_PASS {len(checks)}/{len(checks)}')
