# F2 — TopologyEngine contract

## Purpose

F2 compiles the immutable `CircuitState` into a deterministic canonical wiring graph. It performs structural analysis only. It must not compute voltage, current, impedance, power, MNA matrices or device operating state.

## Input

- `CircuitState` from `electrosim_domain`.
- Enabled `Connection` objects merge their two terminal IDs into one canonical topology node.
- Disabled connections remain observable but do not merge nodes.

## Output

`TopologyGraph` contains:

- `circuitId`, `circuitRevision`, `mode`;
- canonical `TopologyNode` instances;
- terminal → node mapping;
- deterministic enabled/disabled connection lists;
- component → incident node mapping;
- source → incident node mapping;
- structured `TopologyFinding` records.

## Pre-solve findings in F2

- disabled conductor;
- floating/unwired node candidate;
- fully isolated component;
- fully isolated source;
- incompatible phase/polarity tags merged by wiring.

`floatingNode` in F2 is deliberately conservative: it means a node that has no enabled conductor. More advanced electrical floating/island analysis belongs to later component-model/solver phases and must not be guessed here.

## Determinism

Node IDs are derived from the lexicographically smallest terminal ID in each conductor-connected set. Input connection ordering must not change the graph signature.

## Immutability

F2 never mutates `CircuitState`. All public collections in `TopologyGraph` are read-only.

## Forbidden in F2

- Flutter/UI imports;
- voltage/current calculations;
- MNA or matrix solving;
- scenario-specific exceptions;
- mutation of `CircuitState`;
- dependencies on future solver, measurement, energy or diagnostics packages.
