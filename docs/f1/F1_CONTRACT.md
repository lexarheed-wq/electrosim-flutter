# F1 — Pure Dart domain contract

## Scope

F1 establishes the data contracts consumed by later topology and solver phases. It intentionally performs no electrical solving and contains no Flutter/UI code.

### Source of truth

`CircuitState` is the only electrical/structural state container introduced in F1. It carries:

- `circuitId`;
- `revision`;
- `mode` (`dc`, `ac1`, `ac3`, `pv`);
- immutable `components`;
- immutable `connections`;
- immutable `sources`;
- immutable `settings`;
- immutable non-electrical `metadata`;
- `schemaVersion` during serialization.

### Identity and invariants

Typed IDs exist for circuits, components, sources, terminals and connections. IDs are non-empty, trimmed and restricted to a portable ASCII identifier alphabet.

`CircuitState` rejects:

- negative revisions;
- duplicate component/source/connection IDs;
- duplicate terminal IDs across the whole circuit;
- connections referencing missing terminals.

### Serialization

The schema version is currently `1`. Unknown schema versions fail explicitly. JSON metadata/parameter maps are defensively frozen and recursively key-sorted so repeated serialization of the same state is deterministic.

### Dependency rule

`packages/electrosim_domain` may depend only on Dart SDK libraries in production code. `package:flutter` and `dart:ui` are forbidden and checked by both Python and Dart architecture guards.

## Explicitly out of scope

- topology compilation;
- node/branch discovery;
- voltage/current calculation;
- MNA;
- measurements;
- device operating state;
- Canvas/UI;
- storage repository;
- examples or fault scenarios.
