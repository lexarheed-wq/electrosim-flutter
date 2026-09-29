# electrosim_measurements

F4 pure-Dart package. It owns DC measurement semantics and component operating
states. It consumes `CircuitState`, `TopologyGraph`, and `DcSolveResult`; it does
not import Flutter and never infers electrical state from UI state.

F4 scope:
- DC voltage measurement between two topology terminals;
- DC branch-current measurement;
- resistance measurement for a normal resistor in a de-energized circuit;
- explicit invalid-measurement results;
- `DeviceStateEngine` states derived from solved branch results;
- nominal max voltage/current/power warnings.
