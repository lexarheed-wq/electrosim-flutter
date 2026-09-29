# F4 Contract — MeasurementEngine and DC device operating states

## Inputs

F4 consumes the immutable `CircuitState`, its matching `TopologyGraph`, and the
matching solved `DcSolveResult`. It never reads widget or Canvas state.

## Measurement contract

- DC voltage: difference between two solved topology node potentials selected by terminal probes.
- DC current: current already present on the requested solved branch.
- Resistance: F4 intentionally limits ohmmeter mode to a normal resistor component in a circuit with no enabled source. No equivalent-resistance inference is fabricated.
- Unsolved, stale, unsupported or mathematically indeterminate measurements return a structured invalid result; never a decorative zero.

## Device-state contract

`DeviceStateEngine` derives component state from domain condition, component
control state, and solved branch evidence. Supported F4 states are deenergized,
energized, open, closed, disabled, faulted, overloaded and undetermined.

Optional `maxVoltageV`, `maxCurrentA`, and `maxPowerW` parameters generate
structured warnings. Invalid limits are reported rather than silently ignored.

## Architecture

The package is pure Dart and may depend only on domain, topology and DC solver
packages. It has no Flutter/UI, TP, example or fault-scenario dependency.
