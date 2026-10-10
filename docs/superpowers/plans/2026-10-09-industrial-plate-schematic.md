# Industrial plate and schematic implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Deliver synchronized industrial front-view plate and white schematic, reliable cabinet routing, configurable enclosure and supplementary 3D overview on G5.

**Architecture:** One CircuitState and runtime, stable component/terminal/connection IDs. Separate presentation geometry and physical cabinet metadata; views project rather than mutate connectivity. Preserve author positions and legacy saves. A first schematic retains the spatial arrangement; developed command/power folios are explicitly subsequent work.

**Tech Stack:** Flutter 3.38.10, Dart 3.10.9, existing Canvas and CORE-UNIFY packages; no additional 3D or backend dependencies.

**Spec:** docs/superpowers/specs/2026-10-09-industrial-plate-schematic-design.md

## Global Constraints

- Use Flutter 3.38.10 / Dart 3.10.9.
- Target feat/g5-industrial-geometry-20261009, never main.
- Keep CircuitState, physical terminal identity and simulation laws unchanged by presentation switches.
- Plate is frontal realistic wiring; 3D is a supplementary overview, never a second electrical circuit.
- White schematic contains electrical symbols and connections, no physical component textures or instruments.
- Preserve v1/v2 layout saves and add explicit version migration for new physical metadata.
- Distinguish automated qualification, generated visual evidence and physical Mac acceptance.
- Implement and verify tests before claiming completion; source lives in /workspace/electrosim-work.

## Review Focus

- Rotated/multiport equipment must preserve port identity and correct hit targets across views.
- Disconnected or obstructed ducts must not generate an apparently valid route through equipment.
- Switching view during drag/wiring must cleanly cancel interaction without corrupting the author layout.
- Legacy dense projects and malformed serialized physical bounds must load safely or report an explicit error.
- Large displays, small windows and trackpad resizing must not obscure view controls or reset physical placements.

### Task 1: Reliable cabinet duct routing and obstacle validation

**Files:** packages/electrosim_canvas/lib/src/cabinet_duct_wire_planner.dart; apps/electrosim/lib/f18_workspace_wire_safety.dart; focused Canvas/app tests.
**Interfaces:** Preserve CabinetDuctWirePlanner.route(start, end, cabinet); add optional obstacle data and an explicit route collision validator as needed. F18WorkspaceWireSafety remains a general rendering-validity guard; physical routing gets separate obstacle validation to avoid rejecting valid legacy overlapping circuits.
- [x] Add tests for two connected perpendicular ducts, disconnected ducts, obstructing device, deterministic choice and unchanged electrical endpoints.
- [x] Run tests and record expected RED failures.
- [x] Implement graph routing through joined duct centerlines, safe lead-in/out, deterministic shortest viable route, actual obstacle rejection; integrate only cabinet route command, preserving author topology.
- [x] Run focused tests, Canvas regression and app analysis; commit.

### Task 2: Synchronized Platine / Schéma

**Files:** new focused view-mode, symbol projection and renderer modules under apps/electrosim/lib; main.dart integration; Canvas optional presentation styling; layout persistence; focused widget/geometry tests.
**Interfaces:** WorkspaceRepresentation {plate, schematic}; one author CircuitVisualLayout, derived schematic geometry mapped to stable terminal IDs; explicit white background and no physical overlays in schematic.
- [x] Test view command, white schematic without physical visuals, identity/topology/runtime preservation, rotated/multiport symbols and selection/hit testing, saved view preference and repeated switching.
- [x] Run RED tests before implementation.
- [x] Implement switch accessible in desktop and compact controls, symbols for catalogue model families with clear mathematical fallback for abstract loads, electrical lead mapping and distinct wire endpoints, clean interaction cancel; keep plate coordinates intact.
- [x] Run tests, app/Canvas suites and analysis; commit.

### Task 3: Physical enclosure, mounting and supplementary 3D preview

**Files:** Canvas cabinet model/painter; physical equipment metadata module; layout persistence version migration; focused cabinet inspector/preview widgets; main.dart integration; tests.
**Interfaces:** Cabinet envelope with finite positive width/height/depth in mm, mounting plate bounds and common world scale; component mounting metadata kept outside electrical CircuitState. 3D preview projects the existing plate geometry and connection IDs with adjustable camera; no wiring edits while in preview.
- [x] Tests for physical dimensions, enclosure bounds, mechanical DIN anchor, configurable rail/duct sizing, mounting surfaces/interior-door-exterior, v1/v2 migration and new-schema roundtrip, camera rendering without circuit mutation.
- [x] Run RED tests.
- [x] Implement a usable armoire inspector and frontal background, bounds/placement checks, dimension presets, surface assignment and overview with drag rotation/reset; honest generic envelopes for unsupported manufacturer dimensions.
- [x] Run focused/full regressions and analysis; commit.

### Task 4: Real workflow proof, qualification and delivery

**Files:** new end-to-end Flutter widget test and screenshot capture; shared qualification workflow; docs/postv2/p2 and user guide.
**Interfaces:** Exercise Task 1 routes, Task 2 switch and Task 3 enclosure through real production widgets; qualifying SHA must match artifact SOURCE_SHA.
- [ ] Build a populated industrial fixture with actual wired components, two ducts, mounting, select/change view, save/load and Undo/Redo; verify topology and simulation stable.
- [ ] Produce actual Flutter captures for plate, white schematic and overview; inspect images.
- [ ] Run app, Canvas, AC/DC/PV and remaining affected packages, architecture guards, formatting/analyze and web production build.
- [ ] Whole-branch independent review; fix material findings with regression tests.
- [ ] Push isolated branch and PR against G5; run CI, resolve failures, merge qualified result and produce exact-SHA Mac candidate. Report remaining physical Mac acceptance explicitly.

## Autonomy and scope decisions

The user approved the audit and explicitly authorized 100% autonomous execution, GitHub access and all necessary commands. No additional stage confirmations are required. Separate component catalogue artistry and developed multi-folio schematic remain follow-on phases unless necessary to deliver the stated two-view industrial workflow; do not claim manufacturer-certified dimensions.
