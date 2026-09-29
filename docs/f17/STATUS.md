# ElectroSim 2 — F17 integration status

The frozen RC1 baseline remains available on branch `release/electrosim2-rc1`.

Main has advanced beyond RC1 through controlled F17 integration stages:

- F17-R1/R2/R3: application runtime bridge to topology, DC solver, diagnostics and qualified catalog.
- F17-R4: real MeasurementEngine-backed voltmeter/ammeter readings.
- F17-R5: EIE panel backed by DiagnosticEngine evidence only.
- F17-R6: real teacher/student TP lifecycle with publication, start, submission, grading and closure.
- F17-R7: TP diagnostic-sheet persistence and teacher supervision.

Current marker:

```
ELECTROSIM2-F17-R7-INTEGRATION
```

Remaining integration work:

- durable local persistence and reconnect;
- AC1/AC3 runtime routing;
- PV and energy runtime routing;
- multi-device/network teacher/student synchronization;
- final cross-platform release qualification after these integrations.
