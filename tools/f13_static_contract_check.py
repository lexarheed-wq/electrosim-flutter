#!/usr/bin/env python3
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
pkg=root/'packages'/'electrosim_diagnostics'
required=[pkg/'lib/electrosim_diagnostics.dart',pkg/'lib/src/diagnostic_models.dart',pkg/'lib/src/diagnostic_engine.dart',pkg/'test/diagnostic_engine_test.dart',pkg/'tool/validate_eie.dart']
checks=[]
def ok(name,cond): checks.append((name,bool(cond)))
for p in required: ok(f'present {p.name}',p.is_file())
lib='\n'.join(p.read_text(encoding='utf-8',errors='ignore') for p in [pkg/'lib/src/diagnostic_models.dart',pkg/'lib/src/diagnostic_engine.dart'] if p.is_file())
test=(pkg/'test/diagnostic_engine_test.dart').read_text(encoding='utf-8',errors='ignore') if (pkg/'test/diagnostic_engine_test.dart').is_file() else ''
ok('every advice requires evidenceIds','evidenceIds' in lib and 'must cite at least one evidenceId' in lib)
ok('insufficient evidence explicit','DiagnosticReportStatus.insufficientEvidence' in lib)
ok('highlight/localize targets','highlightTargetIds' in lib)
ok('revision coherence enforced','same circuit revision' in lib)
ok('consumes topology findings','TopologyFinding' in lib and 'topology.findings' in lib)
ok('consumes solver result','DcSolveResult' in lib and 'simulation.diagnostics' in lib)
ok('no scenario dependency in runtime lib','electrosim_scenarios' not in lib and 'teacherTruth' not in lib)
ok('no invented advice test','insufficient evidence produces no invented advice' in test)
ok('traceability test','report constructor rejects advice referencing missing evidence' in test)
ok('non contradiction by dedup','emittedCodes' in lib)
failed=[n for n,p in checks if not p]
for n,p in checks: print(('PASS' if p else 'FAIL'),n)
if failed:
 print('F13_STATIC_CONTRACT_FAIL',', '.join(failed)); sys.exit(1)
print(f'F13_STATIC_CONTRACT_PASS {len(checks)}/{len(checks)}')
