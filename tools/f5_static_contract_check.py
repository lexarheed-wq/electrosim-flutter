#!/usr/bin/env python3
from __future__ import annotations
import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files={
 'solver':ROOT/'packages/electrosim_solver_ac/lib/src/solver_ac1.dart',
 'complex':ROOT/'packages/electrosim_solver_ac/lib/src/ac1_complex.dart',
 'result':ROOT/'packages/electrosim_solver_ac/lib/src/ac1_result.dart',
 'tests':ROOT/'packages/electrosim_solver_ac/test/solver_ac1_test.dart',
 'benchmark':ROOT/'packages/electrosim_solver_ac/tool/benchmark.dart',
}
errors=[]
for name,path in files.items():
    if not path.is_file() or path.stat().st_size==0: errors.append(f'missing:{name}')
if not errors:
    solver=files['solver'].read_text(encoding='utf-8')
    complex_src=files['complex'].read_text(encoding='utf-8')
    result=files['result'].read_text(encoding='utf-8')
    tests=files['tests'].read_text(encoding='utf-8')
    for token in ['class SolverAC1','ElectricalMode.ac1','frequencyHz','ac_voltage_source','ac_current_source','inductanceH','capacitanceF','reactanceOhm','_solveLinearSystem']:
        if token not in solver: errors.append(f'ac1-solver-contract-missing:{token}')
    for token in ['class AcComplex','angleDegrees','conjugate','operator /']:
        if token not in complex_src: errors.append(f'complex-contract-missing:{token}')
    for token in ['activePowerW','reactivePowerVar','apparentPowerVA','powerFactor']:
        if token not in result: errors.append(f'power-contract-missing:{token}')
    for token in ['AC1-001 resistive load','AC1-002 inductive load','capacitive load','series R-L','same input is deterministic']:
        if token not in tests: errors.append(f'test-contract-missing:{token}')
result_obj={'phase':'F5','status':'PASS' if not errors else 'FAIL','errors':errors}
print(json.dumps(result_obj,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
