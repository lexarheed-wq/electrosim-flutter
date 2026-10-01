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
