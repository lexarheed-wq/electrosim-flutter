# ElectroSim F18-G2A — Wire Architecture & Smart Placement Design

## Goal

Establish a deterministic, professional wire-layout language before the runtime Canvas is rebuilt. G2A defines geometry, automatic placement, routing, crossing avoidance, conductor lane ordering, visual junction semantics and qualification tests. It does **not** change circuit topology or solve electricity.

## Core principle

Electrical topology and visual routing are separate layers.

`CircuitState / TopologyEngine` owns electrical connectivity.
`WireLayoutEngine` owns only visual geometry.

The routing engine MUST NOT create, remove or reinterpret electrical connections. A visual reroute of the same wire must preserve the same endpoint terminal IDs and net identity.

## 1. Geometry model

A wire is represented as an ordered polyline of orthogonal segments.

- allowed segment orientations: horizontal or vertical only;
- 45° and arbitrary-angle automatic segments are forbidden;
- every bend is an explicit 90° routing point;
- component bodies are obstacles;
- terminals are explicit routing endpoints;
- a junction is an explicit electrical node, never inferred from visual overlap.

Reference grid:
- Canvas grid: 24 px;
- routing track pitch: 24 px;
- terminal stub minimum: 24 px;
- component keep-out: 24 px around body bounds;
- bend keep-out for automatic inline placement: 48 px;
- minimum parallel conductor centerline spacing: 24 px;
- minimum component-to-component visual gap: 48 px;
- terminal visual diameter: 16 px;
- terminal interaction target: 48 px.

## 2. Automatic component placement

### 2.1 Hard rules

An automatically placed inline component MUST:
1. be anchored to a straight segment;
2. have its electrical axis collinear with the host segment;
3. never overlap a 90° bend;
4. remain at least 48 px from the nearest bend after body bounds are considered;
5. preserve at least 24 px of straight terminal stub on each connected side;
6. snap its center to the 24 px component grid;
7. never be moved by a pure reroute operation.

If there is insufficient straight length, the router must first seek a longer/alternative straight route. It must not solve the problem by putting the component on a corner.

### 2.2 Centering and symmetry

For one automatically placed inline component on a branch, the preferred center is the usable branch midpoint.

For multiple inline components on one branch:
- the ordered group is centered around the branch midpoint;
- gaps are equal whenever geometry permits;
- first/last residual wire lengths are balanced;
- maximum centering error due to grid snapping is 12 px;
- no component is moved across another component in electrical order.

User-manual placement may preserve an intentional offset, but snapping, collision and bend keep-out rules still apply.

## 3. DC visual architecture

Basic DC circuits default to a rectangular-loop layout.

Preferred pedagogical organization:
- source: centered on a vertical side branch when compatible with topology;
- protection/control devices: centered and evenly distributed on a straight horizontal branch;
- load: centered on the opposite straight branch when compatible;
- return conductor: clean uninterrupted orthogonal path where possible.

The layout algorithm may choose a wider/taller rectangle to preserve:
- midpoint placement;
- symmetric spacing;
- readable terminal stubs;
- zero automatic crossings.

For branched DC circuits, the rectangle becomes a rail/branch structure while retaining orthogonal geometry and balanced branch spacing.

## 4. AC1 visual architecture

Conductor bundles use stable lane order:
`L → N → PE`.

Rules:
- conductors in one bundle remain parallel through shared corridors;
- lane order must not invert automatically;
- minimum lane pitch: 24 px;
- protective earth remains visually separate and labelled;
- branch breakouts happen on reserved orthogonal channels;
- router prefers common bend stations for conductors of the same bundle.

## 5. AC3 visual architecture

Stable lane order:
`L1 → L2 → L3 → N → PE`.

Rules:
- phase lanes stay parallel where topology permits;
- automatic routing never swaps phase order merely to shorten a path;
- phase identification uses labels/symbols as well as color;
- branch fan-out uses deterministic lane offsets;
- separate conductor bundles keep at least 48 px group separation.

## 6. PV / mixed-energy architecture

Default visual zones, left-to-right where topology permits:
1. PV generation;
2. DC protection/combiner;
3. regulation and/or storage;
4. DC/AC conversion;
5. AC distribution/load.

PV DC `+` and `−` conductors:
- route as a paired bundle;
- keep stable polarity lane order;
- prefer the same bend stations;
- never cross automatically.

The inverter is a visual boundary between DC and AC routing zones. The router must not visually intermingle DC input conductors with AC output conductors when a separated corridor exists.

## 7. Automatic crossing policy

### Hard invariant

**Automatic routing of different nets must produce zero geometric crossings.**

Crossing a different net is not a high-cost fallback; it is forbidden.

If a crossing-free route cannot be found:
1. expand the candidate routing envelope;
2. try an outer routing channel;
3. if still impossible, return an unresolved-route result and leave the existing geometry unchanged.

The router must never silently draw a crossing to declare success.

A user-created manual crossing may exist only with explicit non-junction rendering. A true junction requires an explicit topology node and a visible junction marker.

## 8. Router strategy

Candidate order:
1. direct straight path;
2. one-bend L path;
3. two-bend Z/U path;
4. deterministic Manhattan A* on the routing grid;
5. unresolved route.

Forbidden cells/edges:
- component body + keep-out;
- incompatible terminal keep-out;
- different-net segment;
- different-net intersection point;
- reserved no-route UI regions.

Cost terms for legal candidates:
- path length;
- bend count;
- proximity to obstacles/conductors;
- lane changes;
- unnecessary detour.

Default relative weights:
- grid step: 1;
- bend: +30;
- conductor proximity: +8 per affected grid step;
- lane change: +12;
- crossing another net: forbidden;
- component-body penetration: forbidden.

Tie-breaking must be deterministic: same input state and same viewport-independent routing contract produce the same path.

## 9. Route vs Arrange

Two operations are intentionally separate.

`rerouteWires()`:
- may change wire geometry;
- may not move components;
- may not alter topology.

`arrangeCircuit()`:
- may reposition components according to domain layout rules;
- must preserve topology and relative electrical order;
- then invokes routing.

No normal drag or connection operation may unexpectedly auto-arrange the whole circuit.

## 10. Interaction rules

During wire creation:
- compatible terminal: explicit positive target state;
- incompatible terminal: explicit negative target state;
- preview path obeys the same crossing and obstacle rules as committed routing;
- invalid preview never commits.

During component insertion on an existing segment:
- valid straight insertion location is previewed;
- corner keep-out is visibly rejected;
- if auto-extension is possible, preview the extended rectangular route before commit.

## 11. Junction semantics

- topology junction: visible filled junction marker;
- visual crossing without topology connection: no dot and explicit bridge/gap style;
- automatic router never creates the latter;
- overlapping collinear segments of the same net are normalized into one visual route where possible.

## 12. Required invariants

G2A qualification requires:
- every automatic segment is axis-aligned;
- zero different-net crossings in every auto-routed test case;
- zero automatic components on or inside bend keep-out zones;
- DC inline groups centered/symmetric within grid tolerance;
- AC1/AC3/PV lane order preserved;
- topology unchanged by reroute/arrange;
- router deterministic and reroute idempotent;
- no solver/domain package behavior changed.

## 13. Reference scenarios

The visual prototype and later automated fixtures must cover:
1. DC rectangular single loop: source → breaker → switch → lamp;
2. DC rectangular loop with two series inline components on one branch;
3. DC parallel branches;
4. AC1 L/N/PE distribution with two loads;
5. AC3 L1/L2/L3/N/PE motor/protection path;
6. PV panel → protection → regulator/storage → inverter → AC load;
7. obstacle detour without crossing;
8. impossible crossing-free route returning unresolved;
9. manual explicit non-junction crossing;
10. explicit junction on same/net branch.

## Gate marker

Design-contract qualification marker:
`F18_G2A_WIRE_ARCHITECTURE_SPEC_PASS`

Runtime implementation is a later gate and must not claim this marker as proof of routing correctness by itself.
