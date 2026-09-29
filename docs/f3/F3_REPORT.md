# F3 R1 — Phase report

## Entry condition

F2 is physically validated on the target Monterey toolchain. Evidence is archived
under `reference/f2/`: the observed gate marker is `F2_GATE_PASS`, with 9 topology
tests passing, 94.71% line coverage (161/170), and zero Dart architecture-guard errors.

## Implemented

- pure Dart `electrosim_solver_dc` package;
- Modified Nodal Analysis matrix stamping;
- resistors, ideal voltage/current sources, ideal open/closed switch behavior;
- component open/disabled/short conditions;
- deterministic reference-node selection and unknown ordering;
- partial-pivot Gaussian elimination;
- floating island, contradictory source and singular-matrix diagnostics;
- post-solve matrix residual, KCL and cycle-KVL checks;
- canonical DC-001 through DC-006 tests plus determinism/contract tests;
- benchmark baseline tool on a 40-resistor series circuit;
- F3 Python/Dart architecture guards and manifest.

## Quality gate

The F3 candidate must not progress to AC until the target toolchain proves:

- all F1/F2 regressions green;
- all F3 canonical tests green;
- F3 coverage >= 90%;
- matrix residuals below configured threshold in canonical tests;
- architecture guards green;
- benchmark baseline generated and archived.

Current status: **CANDIDATE — target Dart gate required.**
