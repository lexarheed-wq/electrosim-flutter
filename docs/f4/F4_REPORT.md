# F4 R1 candidate report

Status: **CANDIDATE — target-machine gate required**.

Implemented:
- pure-Dart `MeasurementEngine`;
- structured V/A/Ω measurement results and explicit invalid states;
- de-energized resistor-only Ω rule for F4;
- `DeviceStateEngine` consuming `DcSolveResult`;
- component operating states and nominal-limit warnings;
- F4 architecture guards, static contract, manifest and cumulative validation gate;
- cumulative F1/F2/F3 regression and F3 benchmark replay.

Automatic checks executable without Dart in the packaging environment are
recorded before delivery. Final F4 status becomes PASS only after `F4_GATE_PASS`
is observed with the locked Monterey toolchain.
