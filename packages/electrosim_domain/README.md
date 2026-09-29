# electrosim_domain — F1

Pure Dart domain contracts for the new ElectroSim core.

This package deliberately has **no Flutter dependency**. It defines the immutable/versioned electrical state contracts used by later topology and solver phases:

- typed IDs;
- electrical modes and units;
- structured domain errors;
- `Terminal`;
- `ComponentInstance`;
- `SourceInstance`;
- `Connection`;
- `CircuitState` with schema versioning, deterministic JSON serialization, equality and reference validation.

No voltage/current solving, Canvas, storage implementation, example library or fault library is present in F1.
