# electrosim_solver_dc

Pure Dart F3 DC solver. It consumes a validated `CircuitState` plus its matching
`TopologyGraph` and solves supported two-terminal DC models using Modified Nodal
Analysis (MNA). No Flutter/UI, scenario, TP, measurement or energy dependency is
allowed in this package.

F3 model vocabulary:

- component `resistor` with `parameters.resistanceOhm`;
- component `switch` / `switch_spst` with `controlState.closed`;
- `ComponentCondition.openCircuit`, `disabled`, `shortCircuit`;
- source `dc_voltage_source` / `voltage_source` with `parameters.voltageV`;
- source `dc_current_source` / `current_source` with `parameters.currentA`.

Unsupported or malformed models fail explicitly; they are never coerced to zero.
