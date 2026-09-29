#!/usr/bin/env python3
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
pkg=root/'packages'/'electrosim_scenarios'
checks=[]
def ok(name,cond): checks.append((name,bool(cond)))
required=[
    pkg/'lib/src/fault_scenario_definition.dart',
    pkg/'lib/src/fault_scenario_repository.dart',
    pkg/'lib/src/fault_scenario_validator.dart',
    pkg/'lib/src/f11_fault_scenarios.dart',
    pkg/'test/fault_scenario_repository_test.dart',
    pkg/'tool/validate_fault_scenarios.dart',
]
for p in required: ok(f'present {p.name}',p.is_file())
text='\n'.join(p.read_text(encoding='utf-8',errors='ignore') for p in required if p.is_file())
corpus=(pkg/'lib/src/f11_fault_scenarios.dart').read_text(encoding='utf-8')
definition=(pkg/'lib/src/fault_scenario_definition.dart').read_text(encoding='utf-8')
validator=(pkg/'lib/src/fault_scenario_validator.dart').read_text(encoding='utf-8')
ok('FaultScenarioRepository present','class FaultScenarioRepository' in text)
ok('teacherTruth private model present','class TeacherTruth' in definition)
ok('student payload explicitly separated','studentPayload()' in definition and "'teacherTruth'" not in definition.split('studentPayload()',1)[1].split('canonicalPrivatePayload()',1)[0])
ok('two initial autonomous scenarios',corpus.count("FaultScenarioId('FAULT-DC-")==2)
ok('no exampleId in scenario corpus','exampleId' not in corpus and 'ExampleId' not in corpus)
ok('repair actions are CircuitState mutations','CircuitState apply(CircuitState circuit)' in definition)
ok('reference repairability enforced','not-repairable' in validator and '_rootCausesRemoved' in validator and '_electricalBehaviorChanged' in validator)
ok('deterministic validation stamp','FaultScenarioValidationStamp' in definition and '_fnv1a64' in validator)
ok('teacher truth leak regression test','teacherTruth never leaks into student payload' in (pkg/'test/fault_scenario_repository_test.dart').read_text(encoding='utf-8'))
ok('no hidden fault injection marker','hiddenFaultInjection' not in corpus)
failed=[name for name,passed in checks if not passed]
for name,passed in checks: print(f"{'PASS' if passed else 'FAIL'} {name}")
if failed:
    print('F11_STATIC_CONTRACT_FAIL',', '.join(failed)); sys.exit(1)
print(f'F11_STATIC_CONTRACT_PASS {len(checks)}/{len(checks)}')
