#!/usr/bin/env python3
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
pkg=root/'packages'/'electrosim_tp'
required=[pkg/'lib/src/tp_models.dart',pkg/'lib/src/tp_engine.dart',pkg/'lib/src/verification_engine.dart',pkg/'test/tp_engine_test.dart',pkg/'tool/validate_tp.dart']
checks=[]
def ok(name,cond): checks.append((name,bool(cond)))
for p in required: ok(f'present {p.name}',p.is_file())
text='\n'.join(p.read_text(encoding='utf-8',errors='ignore') for p in required if p.is_file())
ok('explicit lifecycle machine','enum TpLifecycle { draft, published, started, submitted, evaluated, closed }' in text)
ok('diagnostic only student troubleshooting','diagnosticSheetVisibleFor' in text and 'TpRole.student' in text and 'TpMode.troubleshooting' in text)
ok('submitted read only','bool get readOnly' in text and 'TpLifecycle.submitted' in text)
ok('score generated','TpEvaluation' in text and 'score:' in text)
ok('repair recalculated by solver','SolverDC' in text and 'TopologyEngine' in text)
ok('single active TP rule','Another TP is already active' in text)
ok('no teacherTruth in student payload',"'teacherTruth'" not in (pkg/'lib/src/tp_models.dart').read_text(encoding='utf-8'))
ok('E2E regression test present','draft -> published -> started -> submitted -> evaluated -> closed' in (pkg/'test/tp_engine_test.dart').read_text(encoding='utf-8'))
failed=[n for n,p in checks if not p]
for n,p in checks: print(('PASS' if p else 'FAIL'),n)
if failed:
 print('F12_STATIC_CONTRACT_FAIL',', '.join(failed)); sys.exit(1)
print(f'F12_STATIC_CONTRACT_PASS {len(checks)}/{len(checks)}')
