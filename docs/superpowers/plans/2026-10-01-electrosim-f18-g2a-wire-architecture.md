# ElectroSim F18-G2A — Wire Architecture & Smart Placement Implementation Plan

**Goal:** qualify wire geometry, component placement and no-crossing behavior before rebuilding the runtime Canvas.

**Base:** `f18-g1-design-system@41911a87c6d8915b89134bc050b9844c906f652d`

## Task 1 — Freeze the routing contract
- Create machine-readable routing contract.
- Validate numerical invariants and per-domain lane orders.
- Record user requirements and decisions.
- Marker: `F18_G2A_WIRE_ARCHITECTURE_SPEC_PASS`.

## Task 2 — Build one visual routing prototype
Create a single MagicPath review board with four zones:
- DC rectangular;
- AC1/AC3 ordered bundles;
- PV separated zones;
- obstacle/no-crossing example.

The prototype must visibly demonstrate:
- components centered on straight segments;
- no components at bends;
- balanced DC geometry;
- zero automatic wire crossings;
- explicit junction vs non-junction semantics.

## Task 3 — Define pure Dart geometry interfaces
Create interfaces under an isolated future routing package or UI-layout module. No solver coupling.

Candidate value types:
- `WirePoint`
- `WireSegment`
- `OrthogonalWirePath`
- `RoutingObstacle`
- `RoutingLane`
- `InlinePlacementRequest`
- `WireRouteRequest`
- `WireRouteResult`
- `UnresolvedWireRoute`

## Task 4 — TDD geometry primitives
Write failing tests first for:
- horizontal/vertical segment validation;
- bend extraction;
- expanded component keep-out;
- segment intersection;
- same-net normalization;
- different-net crossing detection;
- midpoint/symmetric placement.

## Task 5 — TDD DC arrange policy
Fixtures:
- simple series loop;
- two devices on one branch;
- parallel branches.

Acceptance:
- rectangular loop;
- no bend-hosted devices;
- centered/equal spacing;
- zero crossings.

## Task 6 — TDD bundle routing
AC1 order: `L,N,PE`.
AC3 order: `L1,L2,L3,N,PE`.
PV DC pair: `+,-`.

Acceptance:
- stable lane order;
- common bend stations where possible;
- no automatic lane inversion;
- no automatic crossings.

## Task 7 — Manhattan router
Candidate routing:
1. straight;
2. L;
3. Z/U;
4. deterministic Manhattan A*;
5. unresolved.

Crossing another net and component penetration are hard-invalid, not merely expensive.

## Task 8 — Topology preservation gate
For every reroute and arrange fixture:
- endpoint terminal IDs unchanged;
- net membership unchanged;
- topology signature unchanged;
- solver input unchanged.

## Task 9 — Canvas preview integration
Only after pure geometry tests are green:
- route preview;
- valid/invalid terminal targets;
- bend keep-out preview;
- unresolved route feedback.

No full Canvas rewrite in this task.

## Task 10 — Qualification
Required automated evidence:
- deterministic repeat runs;
- randomized obstacle fixtures with fixed seeds;
- zero-crossing invariant;
- routing idempotence;
- clipping/layout checks;
- no protected solver/domain changes.

Runtime gate marker reserved for implemented router:
`F18_G2A_WIRE_ROUTING_GATE_PASS`.
