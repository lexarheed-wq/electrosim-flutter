# F18 — G6 Canvas and wiring

Gate status: **PASS when the dedicated G6 workflow is green on this branch**.

## Scope

G6 qualifies the production canvas interaction model:

- single selection;
- modifier-only multi-selection with Ctrl/Cmd/Shift;
- explicit deselection by modifier-toggle;
- bulk Delete from the single top-bar delete action;
- direct drag;
- pan/zoom and trackpad transforms;
- terminal hit-testing;
- orthogonal wire routing and non-junction crossing safety;
- live conductor animation driven by runtime current;
- deterministic interaction cancellation.

## Performance correction

PERF-DRAG01 removes global G2A/A* rerouting from the pointer-move hot path. During drag:

- disconnected components update in O(1)-like visual work and keep all wire routes unchanged;
- connected components update only their directly attached preview routes;
- authoritative global routing and crossing validation execute once on pointer release;
- failed final routing restores the pre-drag layout.

The architecture test forbids `_routeWithG2A`/`routeAll` in the live drag branch.

## Multi-selection contract

Multi-selection is never implicit. A normal click replaces the current selection. Ctrl, Cmd or Shift toggles one item into/out of the selection. Bulk Delete removes all selected components, sources and wires while preserving unrelated elements.

## Evidence

The dedicated workflow runs application interaction tests, drag architecture/preview tests, routing robustness, physical terminal tests, viewport tests and the canvas performance budget.

No golden is automatically accepted.

**Marker:** `F18_G6_CANVAS_WIRING_GATE_PASS`
