# F0 - Decisions locked before F1

1. Flutter/Dart is the primary platform.
2. The domain core must be Dart-only and must not import Flutter.
3. The electrical source of truth will be `CircuitState`; no UI or TP copy may become authoritative.
4. Processing pipeline: `CircuitState -> TopologyEngine -> SolverEngine -> SimulationResult`.
5. Examples and fault scenarios are two independent libraries.
6. No historical example or historical fault is imported in F0.
7. Fault injection is not part of the new architecture. A `FaultScenario` will contain its own defective `CircuitState`.
8. Canvas/rendering never computes electricity.
9. Every phase is blocked by its quality gate; no phase is promoted solely because code compiles.
10. F1 cannot start until `flutter analyze` and F0 skeleton tests pass in an environment with Flutter/Dart installed.
