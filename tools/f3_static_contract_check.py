#!/usr/bin/env python3
from __future__ import annotations
import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files={
 'solver':ROOT/'packages/electrosim_solver_dc/lib/src/solver_dc.dart',
 'result':ROOT/'packages/electrosim_solver_dc/lib/src/dc_result.dart',
 'diagnostic':ROOT/'packages/electrosim_solver_dc/lib/src/dc_diagnostic.dart',
 'options':ROOT/'packages/electrosim_solver_dc/lib/src/dc_solver_options.dart',
 'tests':ROOT/'packages/electrosim_solver_dc/test/solver_dc_test.dart',
 'benchmark':ROOT/'packages/electrosim_solver_dc/tool/benchmark.dart',
}
errors=[]
for name,path in files.items():
    if not path.is_file() or path.stat().st_size==0: errors.append(f'missing:{name}')
if not errors:
    solver=files['solver'].read_text(encoding='utf-8')
    tests=files['tests'].read_text(encoding='utf-8')
    diagnostic=files['diagnostic'].read_text(encoding='utf-8')
    for token in ['class SolverDC','_stampConductance','_stampIdealVoltage','_solveLinearSystem','_maxMatrixResidual','_calculateKclResiduals','_calculateKvlResiduals']:
        if token not in solver: errors.append(f'solver-contract-missing:{token}')
    for token in ['floatingElectricalIsland','singularMatrix','contradictoryIdealSource','numericalResidualExceeded']:
        if token not in diagnostic: errors.append(f'diagnostic-contract-missing:{token}')
    for token in ['DC-001','DC-002','DC-003','DC-004','DC-005','DC-006','same circuit and engine version produce identical electrical result']:
        if token not in tests: errors.append(f'test-contract-missing:{token}')
    if '1e-9' not in files['options'].read_text(encoding='utf-8'):
        errors.append('central-residual-tolerance-missing')
result={'phase':'F3','status':'PASS' if not errors else 'FAIL','errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
