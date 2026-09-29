#!/usr/bin/env python3
from __future__ import annotations
import json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files={
 'engine':ROOT/'packages/electrosim_measurements/lib/src/measurement_engine.dart',
 'models':ROOT/'packages/electrosim_measurements/lib/src/measurement_models.dart',
 'device':ROOT/'packages/electrosim_measurements/lib/src/device_state_engine.dart',
 'state':ROOT/'packages/electrosim_measurements/lib/src/operating_state.dart',
 'tests':ROOT/'packages/electrosim_measurements/test/measurement_engine_test.dart',
}
errors=[]
for name,path in files.items():
    if not path.is_file() or path.stat().st_size==0: errors.append(f'missing:{name}')
if not errors:
    engine=files['engine'].read_text(encoding='utf-8')
    device=files['device'].read_text(encoding='utf-8')
    models=files['models'].read_text(encoding='utf-8')
    tests=files['tests'].read_text(encoding='utf-8')
    for token in ['class MeasurementEngine','MeasurementKind.voltageDc','MeasurementKind.currentDc','MeasurementKind.resistance','energizedResistanceMeasurement','branchCurrentUnavailable']:
        if token not in engine and token not in models: errors.append(f'measurement-contract-missing:{token}')
    for token in ['class DeviceStateEngine','ComponentOperatingCode.overloaded','maxVoltageV','maxCurrentA','maxPowerW','component:${component.id.value}']:
        if token not in device: errors.append(f'device-state-contract-missing:{token}')
    for token in ['DC voltage is read from solved node potentials','DC current is read from the solved branch result','resistance is permitted for a de-energized normal resistor','max voltage/current/power limits produce overload warnings','switch state comes from controlState plus solved branch evidence']:
        if token not in tests: errors.append(f'test-contract-missing:{token}')
result={'phase':'F4','status':'PASS' if not errors else 'FAIL','errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
