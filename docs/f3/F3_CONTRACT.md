# F3 — SolverDC contract

## Scope

F3 is a pure Dart deterministic DC solver based on Modified Nodal Analysis (MNA).
It consumes the same immutable `CircuitState` and the matching `TopologyGraph`.
The UI is not involved in any electrical calculation.

## Supported F3 models

- two-terminal resistor (`resistanceOhm > 0`);
- ideal SPST switch (`controlState.closed`);
- component conditions open/disabled/short-circuit;
- ideal DC voltage source (`voltageV`);
- ideal DC current source (`currentA`);
- enabled conductors are already compiled by F2 into topology nodes.

All parameters must be finite and explicit. Unsupported models or malformed data are
errors; F3 never replaces a failed calculation with zero.

## Numerical method

- canonical MNA unknown ordering;
- partial-pivot Gaussian elimination;
- central `DcSolverOptions` pivot/residual tolerances;
- singular matrix detection;
- explicit floating-island detection;
- explicit contradictory ideal source detection;
- matrix residual verification after solve.

## Physical validation

Every solved result contains:

- node voltages;
- branch voltage/current/power where defined;
- KCL residual per node;
- KVL residual for each independent cycle found in a deterministic spanning forest;
- engine version and circuit revision.

## F3 exclusions

- AC/phasors;
- device operating-state inference (F4);
- MeasurementEngine (F4);
- energy, EIE, TP, scenario logic;
- Flutter/UI dependencies;
- scenario-specific hard-coded values.
