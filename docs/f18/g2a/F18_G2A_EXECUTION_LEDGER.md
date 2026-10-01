# F18-G2A Execution Ledger

Base: `f18-g1-design-system@41911a87c6d8915b89134bc050b9844c906f652d`

User decision captured on 2026-10-01:
- DC circuits should prefer rectangular wire structures.
- Components must not be automatically placed on right-angle bends.
- Components should be symmetrical and centered on straight wire segments, especially in DC.
- AC, PV and other domains should use clean ordered conductor routes.
- Automatic routing should not create confusing overlaps or wire crossings.

Ruling: G2A is inserted before the full Canvas/cabling gate because wire geometry influences component rendering, interaction, measurement readability and pedagogical clarity.

Ruling: automatic different-net crossings are forbidden. When no crossing-free route exists, the router must return unresolved rather than silently crossing.

Ruling: pure rerouting never moves components. Component movement belongs to an explicit arrange operation.

Ruling: the 24 px visual grid established in the F18 workspace becomes the routing track pitch. Component auto-placement keeps 48 px from bends and uses a 48 px minimum interaction target for terminals.

No merge to `main` is performed by this specification branch.


## MagicPath visual prototype

Reference board:
- projectId: `456415562449448960`
- componentId: `456432394111688704`
- revisionId: `456432394111688705`
- name: `Reference/Wire Architecture G2A`
- size: 1440×1100

The board demonstrates four required visual cases in one review surface: DC rectangular layout, ordered AC conductor bundles, separated PV DC/AC zones, and obstacle detour with automatic crossings forbidden.


## Runtime geometry milestone — 2026-10-01

Implementation branch: `f18-g2a-wire-routing`.

TDD evidence:
- RED run `36886114738`: geometry types intentionally absent; analyzer failed on missing `OrthogonalWirePath`, `OrthogonalSegment`, `RoutingObstacle`, `InlinePlacementPolicy`.
- First GREEN run `36886812371`: orthogonal geometry + centered inline placement passed analysis, targeted tests, Canvas non-golden regressions and protected electrical-scope guard.
- Router RED run `36887054274`: missing `OrthogonalWireRouter`, `WireRouteResult`, `WireRouteSafety` and `WireRouteFailure` confirmed.
- Router GREEN run `36887255090`: analysis PASS, all targeted G2A geometry/router tests PASS, Canvas non-golden regressions PASS, protected electrical engine scope PASS.

Implemented so far:
- orthogonal horizontal/vertical segment contract;
- explicit bend extraction;
- perpendicular intersection detection;
- expanded routing obstacles;
- centered/symmetric inline component placement with bend keep-out and terminal stubs;
- deterministic direct/L/U outer-channel router;
- obstacle avoidance;
- different-net crossing rejection;
- unresolved result rather than forced crossing;
- deterministic identical-input output.

Still required before full `F18_G2A_WIRE_ROUTING_GATE_PASS`:
- Manhattan A* fallback on the 24 px routing grid;
- AC1/AC3 stable lane-bundle planner;
- PV paired DC corridor + DC/AC zone planner;
- DC rectangular circuit arrange policy tied to visual roles;
- route idempotence/property/randomized fixtures;
- Canvas preview/commit integration;
- explicit junction vs manual non-junction rendering;
- final full application regression and visual validation.

No solver, topology, diagnostics, measurement, PV engine, energy, TP or storage package was modified by these routing milestones.
