#!/usr/bin/env python3
from __future__ import annotations
import json,re,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
files={
 'pv_solver':ROOT/'packages/electrosim_pv/lib/src/solver_pv.dart',
 'pv_result':ROOT/'packages/electrosim_pv/lib/src/pv_result.dart',
 'pv_tests':ROOT/'packages/electrosim_pv/test/solver_pv_test.dart',
 'energy_engine':ROOT/'packages/electrosim_energy/lib/src/energy_engine.dart',
 'energy_models':ROOT/'packages/electrosim_energy/lib/src/energy_models.dart',
 'energy_tests':ROOT/'packages/electrosim_energy/test/energy_engine_test.dart',
 'contract':ROOT/'docs/f7/F7_CONTRACT.md',
 'pv_benchmark':ROOT/'packages/electrosim_pv/tool/benchmark.dart',
 'energy_benchmark':ROOT/'packages/electrosim_energy/tool/benchmark.dart',
}
errors=[]
for name,path in files.items():
    if not path.is_file() or path.stat().st_size==0: errors.append(f'missing:{name}')
if not errors:
    pv=files['pv_solver'].read_text(encoding='utf-8')
    pvr=files['pv_result'].read_text(encoding='utf-8')
    pvt=files['pv_tests'].read_text(encoding='utf-8')
    eng=files['energy_engine'].read_text(encoding='utf-8')
    enm=files['energy_models'].read_text(encoding='utf-8')
    ent=files['energy_tests'].read_text(encoding='utf-8')
    for token in ['class SolverPV','ElectricalMode.pv','pv_array','pv_inverter','mppVoltageV','mppCurrentA','irradianceWm2','cellTemperatureC','inverter.condition','inputVoltageOutOfRange','inverterOutputPowerW','inverterConversionLossW']:
        if token not in pv: errors.append(f'pv-solver-contract-missing:{token}')
    for token in ['PvInverterState','pvAvailablePowerW','pvDrawnPowerW','curtailedPowerW','inverterOutputVoltageRmsV','inverterOutputPowerW','inverterConversionLossW']:
        if token not in pvr: errors.append(f'pv-result-contract-missing:{token}')
    for token in ['PV-001 inverter fault conditions stop downstream output physically','low irradiance reduces available power','temperature coefficients are applied explicitly','same PV input is deterministic','missing environmental settings use documented solver defaults','invalid environmental settings fail explicitly','degraded inverter still enforces its DC input window','zero PV operating voltage cannot invent available current or AC output','zero reference irradiance is handled deterministically without division by zero']:
        if token not in pvt: errors.append(f'pv-test-contract-missing:{token}')
    for token in ['class EnergyEngine','Duration elapsed','inputEnergyWh','outputEnergyWh','lossEnergyWh']:
        if token not in eng: errors.append(f'energy-engine-contract-missing:{token}')
    for token in ['EnergyPowerSample.fromPvResult','unbalancedPower','inputEnergyKWh','outputEnergyKWh','cumulativeEfficiency','class EnergyHistory']:
        if token not in enm: errors.append(f'energy-model-contract-missing:{token}')
    for token in ['ENERGY-001 integrates W into Wh and kWh','multiple intervals accumulate deterministically','invalid power balance is rejected','bounded EnergyHistory']:
        if token not in ent: errors.append(f'energy-test-contract-missing:{token}')
    contract=files['contract'].read_text(encoding='utf-8')
    for token in ['pas une courbe I-V complète','aucune valeur cachée','input = output + loss','Wh = W × h']:
        if token not in contract: errors.append(f'doc-contract-missing:{token}')

    # F7-R2 regression guard: literal IDs used by PV fixtures/benchmarks must obey
    # the F1 ValueId grammar. Electrical polarity belongs to PhaseTag/TerminalRole,
    # not to unsupported punctuation such as '+' in an identifier.
    id_pattern=re.compile(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$')
    constructor_pattern=re.compile(r"(?:CircuitId|ComponentId|SourceId|TerminalId|ConnectionId)\(\s*'([^']+)'\s*\)")
    wire_pattern=re.compile(r"_wire\(\s*'([^']+)'\s*,\s*'([^']+)'\s*,\s*'([^']+)'")
    for source_name in ('pv_tests','pv_benchmark'):
        text=files[source_name].read_text(encoding='utf-8')
        literal_ids=[m.group(1) for m in constructor_pattern.finditer(text)]
        for m in wire_pattern.finditer(text): literal_ids.extend(m.groups())
        for value in literal_ids:
            if not id_pattern.fullmatch(value):
                errors.append(f'invalid-literal-id:{source_name}:{value}')
result={'phase':'F7','status':'PASS' if not errors else 'FAIL','errors':errors}
print(json.dumps(result,indent=2,ensure_ascii=False)); sys.exit(0 if not errors else 1)
