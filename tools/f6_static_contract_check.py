#!/usr/bin/env python3
from __future__ import annotations
import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files={
 'solver':ROOT/'packages/electrosim_solver_ac/lib/src/solver_ac3.dart',
 'result':ROOT/'packages/electrosim_solver_ac/lib/src/ac3_result.dart',
 'diagnostic':ROOT/'packages/electrosim_solver_ac/lib/src/ac3_diagnostic.dart',
 'tests':ROOT/'packages/electrosim_solver_ac/test/solver_ac3_test.dart',
 'benchmark':ROOT/'packages/electrosim_solver_ac/tool/benchmark_ac3.dart',
 'contract':ROOT/'docs/f6/F6_CONTRACT.md',
}
errors=[]
for name,path in files.items():
    if not path.is_file() or path.stat().st_size==0: errors.append(f'missing:{name}')
if not errors:
    solver=files['solver'].read_text(encoding='utf-8')
    result=files['result'].read_text(encoding='utf-8')
    tests=files['tests'].read_text(encoding='utf-8')
    for token in ['class SolverAC3','ElectricalMode.ac3','PhaseTag.l1','PhaseTag.l2','PhaseTag.l3','PhaseTag.neutral','_solveLinearSystem','phase_sequence_probe','phaseLoss','neutralCurrent']:
        if token not in solver: errors.append(f'ac3-solver-contract-missing:{token}')
    for token in ['Ac3PhaseSequence','phaseVoltages','lineCurrents','lineToLineVoltages','neutralCurrent','missingPhases','currentBalanced','phaseOrderObservations']:
        if token not in result: errors.append(f'ac3-result-contract-missing:{token}')
    for token in ['AC3-001 balanced star','balanced delta','unbalanced four-wire star','three-wire unbalanced star','AC3-002 loss of L2','AC3-003 swapping two physical conductors','same input is deterministic']:
        if token not in tests: errors.append(f'test-contract-missing:{token}')
    if 'phase × 3' not in files['contract'].read_text(encoding='utf-8'):
        errors.append('contract-missing-no-x3-rule')
result_obj={'phase':'F6','status':'PASS' if not errors else 'FAIL','errors':errors}
print(json.dumps(result_obj,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
