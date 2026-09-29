# ElectroSim 2 — F17 integration status

The frozen RC1 baseline remains available on branch `release/electrosim2-rc1`.

Main has advanced beyond RC1 through controlled F17 integration stages:

- F17-R1/R2/R3: application runtime bridge to topology, DC solver, diagnostics and qualified catalog.
- F17-R4: real MeasurementEngine-backed voltmeter/ammeter readings.
- F17-R5: EIE panel backed by DiagnosticEngine evidence only.
- F17-R6: real teacher/student TP lifecycle with publication, start, submission, grading and closure.
- F17-R7: TP diagnostic-sheet persistence and teacher supervision.
- F17-R8: durable local CircuitState persistence with atomic replacement/recovery, explicit save/resume actions, and TP lifecycle reconstruction through validated engine transitions.
- F17-R9: AC1/AC3 runtime routing to the qualified AC solvers; DC-only measurement and EIE capabilities remain explicitly unavailable in AC instead of fabricating values.
- F17-R10: PV runtime routing to the qualified SolverPV, solver-backed PV evidence in the application, and EnergyEngine accumulation driven only by explicit simulation time.

Current marker:

```
ELECTROSIM2-F17-R10-INTEGRATION
```

Remaining integration work:

- multi-device/network teacher/student synchronization;
- final cross-platform release qualification after these integrations.
