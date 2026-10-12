# Metal restoration and integration audit implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Execute inline; request one final independent review.

**Goal:** Restore the already developed satin metal plate and verify delivered industrial/TP work by content and behavior.

**Architecture:** Keep the current G5 circuit, geometry, cabinet and component assets. Restore the drawing helper at the canvas boundary; render authored cabinet plates with the same material. Schematic remains white. Record integration evidence separately from pending feature development.

**Tech Stack:** Flutter 3.38.10, Dart, Python, Chromium, GitHub Actions.

**Spec:** User request in this conversation; original material specification in `docs/g5-metal-mounting-plate/README.md` and PR #63.

## Global constraints

- Base: current G5 `709bac5ce562fe2ee0215b58ae959c82e28bdda7`; preserve newer native assets and pneumatic work.
- No old branch merge and no electrical state or terminal changes.
- No claim of physical Mac/phone acceptance.
- Existing authorization includes fixes, qualification and merge; execute without further approval.

## Review focus

- Empty physical canvas must show metal, while schematic stays uniformly white.
- Cabinet plate must use metal within authored dimensions, without a second oversized sheet behind the enclosure.
- Zoom/pan must carry the surface and fixings with world geometry.
- Wire crossover masks must match the surface beneath each crossing.
- Current components, QR resume, read-only submission and teacher marking must survive restoration.

## Task 1: Audit delivered work

- [x] Inspect deletion history and compare PR deliverables against current code, assets and behavior tests.
- [x] Write `docs/qualification/G5_INTEGRATION_AUDIT_20261012.md`, distinguishing present, lost and pending work.
- [x] Run existing app/canvas regressions as baseline; record concrete failures before fixes.

## Task 2: Restore material and regression protection

**Files:** `packages/electrosim_canvas/lib/src/metal_mounting_plate.dart`, `circuit_scene_painter.dart`, `cabinet_fixture_painter.dart`; `packages/electrosim_canvas/test/metal_mounting_plate_test.dart`; current visual goldens.

**Interfaces:** Restore `paintMetalMountingPlate(Canvas, {required Size viewportSize, required Rect screenBounds, required double scale})`, `mountingPlateSurfacePaint(Rect)`, `mountingPlateBounds(Iterable<Rect>)` from original material. Canvas chooses standalone sheet or authored cabinet plate. Existing physical/schematic flags remain authoritative.

- [x] Write raster assertions using the real `CircuitScenePainter`: physical background is metal rather than grid, schematic is white; cabinet surface is metal; panned/scaled sheet follows layout. First run must fail on current pixels.
- [x] Restore original helper and integrate it with current cabinet renderer and crossover masks.
- [x] Run raster tests and full canvas suite; refresh only visual references changed by the material and inspect real current-workspace screenshots.
- [x] Run app analysis/full suite, TP browser journey and architecture gates.

The independent review additionally recovered three lost routing/layout preservation paths and their deleted test file. Five regressions now cover function behavior and actual workspace interactions, retaining envelope, rails/ducts, mounts, rotations and anchors. The two active widget failures were reproduced with the historical omissions before restoration.

## Task 3: Deliver and verify integration

- [x] Obtain independent review of the complete diff and audit evidence.
- [ ] Commit and open PR against current G5; verify relevant GitHub workflows at exact final head.
- [ ] Recheck base before merge; merge only after passing qualification.
- [ ] Verify postmerge runtime/browser/visual/Mac jobs and artifact SHA/digests; report limits and remaining pending work.
