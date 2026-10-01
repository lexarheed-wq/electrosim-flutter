# ElectroSim F18-G2A — Wire Routing Qualification Report

## Status

Qualification marker: `F18_G2A_WIRE_ROUTING_GATE_PASS`

Qualified branch: `f18-g2a-wire-routing`  
Qualified code head before this report-only commit: `47fcb5c4d6be7ebd9c5e33587c30f2a11565db62`

Dedicated final qualification run: `36924756020`

## User requirements implemented

G2A was introduced to guarantee:
- rectangular and visually balanced DC layouts;
- no automatic component placement on right-angle bends;
- centered/symmetric inline components on straight segments;
- ordered and separated AC conductors;
- ordered PV DC polarity routes and DC/AC zone separation;
- zero automatic wire crossings between different nets;
- unresolved routing rather than forced or ambiguous crossings.

## Qualified architecture

### Orthogonal geometry
- automatic segments: horizontal/vertical only;
- routing grid: 24 px;
- bend keep-out: 48 px;
- minimum terminal stub: 24 px;
- terminal visual diameter: 16 px;
- terminal interaction target: 48 px.

### Routing
Candidate strategy:
1. straight;
2. one-bend;
3. two-bend / outer channel;
4. deterministic Manhattan A*;
5. unresolved.

Different-net crossing is hard-invalid. Component-body penetration is hard-invalid.

### DC
- rectangular-loop arrange policy;
- source/load midpoint placement on opposite side branches;
- symmetric centered inline devices on straight branches;
- insufficient branch length returns unresolved instead of moving a component onto a bend.

### AC / PV
- AC1 order: `L, N, PE`;
- AC3 order: `L1, L2, L3, N, PE`;
- PV DC pair order: `+, -`;
- stable lane order;
- separated PV DC and AC visual zones.

### Canvas integration
Smart routing is integrated in `SimulatorCanvas` as an explicit opt-in path:
- routed committed geometry;
- smart wire preview;
- no implicit topology mutation;
- explicit junction rendering;
- manual non-junction crossing rendering with gap/bridge semantics.

## Topology preservation

`CircuitWireLayoutEngine` operates on `CircuitVisualLayout` only. Routing:
- preserves connection endpoint terminal IDs;
- does not mutate `CircuitState`;
- does not change solver input;
- leaves component placement unchanged during pure reroute;
- preserves the previous visual route if no legal route can be found.

## Robustness

Deterministic robustness fixtures include:
- 100 seeded obstacle layouts;
- 60 seeded different-net barrier fixtures;
- repeated identical-input route verification;
- routeAll idempotence;
- impossible crossing-free cases;
- obstacle detours;
- Manhattan A* multi-turn corridor;
- junction and non-junction semantics.

## Final automated evidence

Run `36924756020` on head `47fcb5c4d6be7ebd9c5e33587c30f2a11565db62`:

- Flutter/Dart locked toolchain: PASS
- Canvas analyze: PASS
- G2A targeted tests: **35 PASS**
- Canvas non-golden regressions: **18 PASS**
- Application analyze: PASS
- Application non-golden regressions: **72 PASS**
- historical visual baselines preserved: `F18_G2A_LEGACY_GOLDENS_PRESERVED`
- protected electrical-engine scope: PASS
- final marker: `F18_G2A_WIRE_ROUTING_GATE_PASS`

Cross-platform build evidence already green on the smart-routing head family:
- Android: PASS
- iOS: PASS
- macOS: PASS
- Windows: PASS
- Linux: PASS
- Evidence bundle: PASS

## Historical F8 workflow

The legacy `f8` workflow remains red on this branch because its `F15-F14-freeze` step compares the modern F17/G1/G2A tree against an F14 baseline and therefore reports numerous pre-existing later-phase changes.

This is not used as G2A qualification evidence. G2A instead uses:
- exact protected-package drift checks;
- Canvas regression tests;
- application regression tests;
- historical-golden preservation;
- exact-head G2A workflow.

No F8 baseline or historical freeze evidence was rewritten to hide this mismatch.

## Visual reference

MagicPath:
- project: `ElectroSim F18 — Professional Design System`
- projectId: `456415562449448960`
- reference: `Reference/Wire Architecture G2A`
- componentId: `456432394111688704`
- revisionId: `456432394111688705`
- size: 1440×1100

The board covers:
- DC rectangular layout;
- ordered AC conductors;
- PV DC/AC separation;
- obstacle detour with automatic crossings forbidden.

## Scope

Modified production scope for G2A is restricted to `packages/electrosim_canvas/**`.

No production modification was made to:
- domain;
- topology;
- DC/AC solvers;
- PV engine;
- energy;
- measurements;
- diagnostics;
- TP;
- storage.

## Outcome

G2A routing architecture is qualified.

`F18_G2A_WIRE_ROUTING_GATE_PASS`
