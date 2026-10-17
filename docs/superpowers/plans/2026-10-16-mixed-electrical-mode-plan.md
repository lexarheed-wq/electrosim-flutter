# Mixed Electrical Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a user-facing Mixed design mode that presents CC, AC, AC3, and PV subcircuits together on one board while the runtime solves each domain with its existing specialized engine.

**Architecture:** Keep electrical subnetworks homogeneous and persist them as an expanded `ElectricalProject`; the mixed mode is a board/editor orchestration mode, never an input to a specialized solver. Render all subnetworks on one shared canvas/layout, reject conductive wires crossing domains, and use validated typed links for PLC/actuator and converter coupling.

**Tech Stack:** Dart, Flutter, `electrosim_domain`, `electrosim_multiphysics`, `electrosim_controls`, existing DC/AC1/AC3/PV solvers, Flutter widget tests.

**Spec:** `docs/superpowers/specs/2026-10-16-mixed-electrical-mode-design.md`

## Global Constraints

- A mixed board contains homogeneous solver subnetworks in the `dc`, `ac1`, `ac3`, or `pv` domains; never pass `mixed` to a specialized solver.
- Wires stay within one electrical domain; only validated typed links or modeled conversion components may exchange state or power across domains.
- The simulation clock advances once per project tick; any corrective solve for new PLC outputs or converter coupling uses zero elapsed time.
- PLC supply/program errors, missing or invalid links, interlock conflicts, and unsupported conversions leave affected outputs/actuators in a safe state and emit actionable diagnostics.
- Existing single-mode circuits and saved mixed projects remain loadable with their stable component IDs and wiring.
- This checkout already contains unrelated uncommitted edits, including several files named by this plan. Never stage a whole dirty file; stage only the task's hunks and inspect `git diff --cached` before every commit.
- Every implementation task follows test-first, runs its focused test before and after implementation, and commits only its listed files.

## Review Focus

- A requested but missing solver domain must not prevent other present domains from solving; Task 2 tests partial domain sets.
- A direct wire between unlike domains must be rejected while a typed PLC/actuator link remains valid; Tasks 1 and 3 test both paths.
- PLC power loss, invalid Ladder output, or a dangling/duplicate actuator link must release the target contactor; Task 3 tests each condition.
- One physical contactor with interlocking/protection must not be closed by a PLC link when an AC3 interlock or protection blocks it; Task 3 tests an interlocked pair and trip state.
- Legacy projects with independent saved layouts and relay links must migrate without dropping elements; Task 5 tests round-trip and migration.

---

### Task 1: Generalize the project model for a mixed board

**Files:**
- Modify: `packages/electrosim_domain/lib/src/electrical_types.dart`
- Modify: `packages/electrosim_multiphysics/lib/src/electrical_project.dart`
- Test: `packages/electrosim_multiphysics/test/electrical_project_test.dart`

**Interfaces:**
- Produces `ElectricalMode.mixed` for the board selector only; homogeneous `CircuitState.mode` values continue to identify solver domains.
- Produces `CrossNetworkActuatorLink({required String id, required String plcNetworkId, required String plcComponentId, required String outputAddress, required String targetNetworkId, required String contactorId})`; `targetNetworkId` must resolve to an AC1 or AC3 network.
- Produces `CrossNetworkConverterLink({required String id, required String inputNetworkId, required String converterComponentId, required String outputNetworkId})` for converter boundaries whose input/output are modeled in separate homogeneous networks.
- Produces `ElectricalProject.emptyMixedBoard()` containing empty homogeneous CC, AC1, AC3, and PV networks with each solver's normal default settings.
- `ElectricalProject` accepts one homogeneous network for each active solver domain (`dc`, `ac1`, `ac3`, `pv`), with any subset present, and stores actuator/converter links alongside existing relay and feedback links.

- [ ] **Step 1: Write failing project model tests**

Add tests that construct a four-domain project; construct partial DC+AC3 and PV+AC1 projects; reject duplicate domains, mixed-mode `ElectricalNetwork.circuit` objects, dangling/wrong-type contactor links, invalid Q addresses, reused PLC outputs and invalid converter/domain combinations; and round-trip both link types while continuing to decode v1 JSON with no new link keys.

- [ ] **Step 2: Run the project tests and verify the expected failures**

Run: `dart test test/electrical_project_test.dart` from `packages/electrosim_multiphysics`.
Expected: compile/runtime failures for the missing mixed board selector and actuator link support.

- [ ] **Step 3: Implement the mixed board/project contract**

Add `ElectricalMode.mixed` as a UI/project selection value and `ElectricalProject.emptyMixedBoard()` with the four empty domain circuits and their normal settings. Keep each persisted `ElectricalNetwork.circuit.mode` restricted to a solver domain. Expand `ElectricalProject._validate` to accept one network per active solver mode up to the four supported domains, validate both typed link classes, bump the project schema to version 2, and make `fromJson` migrate version 1 by defaulting absent actuator/converter link fields to empty lists.

- [ ] **Step 4: Run the project tests**

Run: `dart test test/electrical_project_test.dart`.
Expected: all project validation, v1 compatibility, and serialization tests pass.

- [ ] **Step 5: Commit the project model**

```bash
git add packages/electrosim_domain/lib/src/electrical_types.dart packages/electrosim_multiphysics/lib/src/electrical_project.dart packages/electrosim_multiphysics/test/electrical_project_test.dart
git commit -m "feat: model mixed electrical projects"
```

### Task 2: Orchestrate all present domain solvers

**Files:**
- Modify: `apps/electrosim/lib/runtime/electrical_project_runtime_engine.dart`
- Modify: `apps/electrosim/lib/runtime/electrosim_runtime_engine.dart`
- Test: `apps/electrosim/test/f17_runtime_engine_test.dart`
- Test: `apps/electrosim/test/electrical_project_runtime_test.dart`

**Interfaces:**
- Consumes `ElectricalProject.networks` and the typed link contracts from Task 1.
- Produces one `ElectroSimRuntimeSnapshot` per network in `ElectricalProjectRuntimeSnapshot.networks`, plus diagnostics scoped to the affected network/link.
- Converter exchange consumes and produces `CrossNetworkConverterLink`; it never merges unlike-domain nodes.

- [ ] **Step 1: Write failing runtime tests**

Add `mixedRuntimeSolvesEveryPresentDomainWithItsOwnSolver`, asserting the correct solver result is populated for DC, AC1, AC3, and PV subnetworks in one tick; add `mixedRuntimeAllowsAnySubsetOfDomains`, asserting DC+AC3 and PV+AC1 solve without a hard requirement for DC+AC3; add `mixedRuntimeAdvancesElapsedOnce`, asserting project elapsed time and stateful PV/PLC components advance once per requested duration.

- [ ] **Step 2: Run the focused runtime tests and verify failure**

Run: `flutter test test/electrical_project_runtime_test.dart` from `apps/electrosim`.
Expected: failures caused by the current runtime's fixed DC+AC3 requirement and lack of generalized domain orchestration.

- [ ] **Step 3: Implement domain iteration and snapshots**

Dispatch each homogeneous network through `ElectroSimRuntimeEngine.advance` using its own solver mode. Preserve prior state per network, advance elapsed time once, and report solver failures without suppressing successful results from unrelated domains. Keep PLC ladder scan and cross-domain correction in the project-level coordinator. Reject `ElectricalMode.mixed` at the single-network runtime boundary with an actionable `ArgumentError` so a render-only board cannot reach a solver.

- [ ] **Step 4: Run runtime regressions**

Run: `flutter test test/f17_runtime_engine_test.dart`, `flutter test test/electrical_project_runtime_test.dart`, and `flutter test test/f17_pv_energy_runtime_test.dart`.
Expected: generalized domain tests pass and current PV energy behavior remains unchanged.

- [ ] **Step 5: Commit the runtime orchestration**

```bash
git add apps/electrosim/lib/runtime/electrical_project_runtime_engine.dart apps/electrosim/lib/runtime/electrosim_runtime_engine.dart apps/electrosim/test/f17_runtime_engine_test.dart apps/electrosim/test/electrical_project_runtime_test.dart
git commit -m "feat: orchestrate mixed solver domains"
```

### Task 3: Add safe PLC-to-contactor and converter links

**Files:**
- Modify: `apps/electrosim/lib/runtime/electrical_project_runtime_engine.dart`
- Modify: `packages/electrosim_controls/lib/src/electromechanical_control_engine.dart`
- Test: `apps/electrosim/test/electrical_project_runtime_test.dart`
- Test: `packages/electrosim_controls/test/electromechanical_control_engine_test.dart`

**Interfaces:**
- Consumes `CrossNetworkActuatorLink` from Task 1 and per-network snapshots from Task 2.
- The project runtime projects PLC Q state onto the linked AC/AC3 contactor as a command (`plcCommand`); the electromechanical coordinator still owns actuation and runs interlock/protection logic before final state.

- [ ] **Step 1: Write failing direct-actuator tests**

Add tests that PLC Q0 true actuates the linked AC3 contactor and passes current through its power poles; Q0 false, invalid Ladder, invalid PLC supply, missing link target, and duplicate link each leave it open with a diagnostic; an interlocked pair never closes both when both Q outputs are true. Also verify an AC1 contactor can be linked from the DC PLC.

- [ ] **Step 2: Run focused tests and verify failure**

Run: `flutter test test/electrical_project_runtime_test.dart` from `apps/electrosim` and `dart test test/electromechanical_control_engine_test.dart` from `packages/electrosim_controls`.
Expected: direct-link tests fail because the runtime currently requires a physical `relay_coil` and AC3 dry contact pair.

- [ ] **Step 3: Implement direct command projection**

Read each validated PLC output from its runtime state, project the command onto the target AC1/AC3 contactor, and pass it to the existing coordinator. A false or unavailable output releases the contactor. Keep the existing physical relay link path functional and do not bypass contactor protections or mechanical/electrical arbitration.

- [ ] **Step 4: Implement and verify conversion-domain behavior**

Add tests for a PV-side network with `pv_inverter` linked by `CrossNetworkConverterLink` to an AC1 or AC3 load network, asserting the inverter's AC boundary feeds the downstream solver and downstream load power is reflected into the PV solve; unsupported or absent converter links must not copy values or energy between domains. Use at most 8 deterministic coupling passes; convergence requires both output RMS voltage and real power to change by no more than 0.1% between passes (with a 0.01 V and 0.1 W absolute floor). If the limit is reached, disable the boundary and report non-convergence. Implement only coupling supported by existing converter model contracts; keep unsupplied conversion paths safely open with diagnostics.

- [ ] **Step 5: Run focused runtime/control/PV tests**

Run: `flutter test test/electrical_project_runtime_test.dart` from `apps/electrosim`, `dart test test/electromechanical_control_engine_test.dart` from `packages/electrosim_controls`, and `dart test test/solver_pv_test.dart` from `packages/electrosim_pv`.
Expected: direct PLC control, protection/interlock, and existing PV conversion tests pass.

- [ ] **Step 6: Commit typed inter-domain behavior**

```bash
git add apps/electrosim/lib/runtime/electrical_project_runtime_engine.dart apps/electrosim/test/electrical_project_runtime_test.dart packages/electrosim_controls/lib/src/electromechanical_control_engine.dart packages/electrosim_controls/test/electromechanical_control_engine_test.dart
git commit -m "feat: link PLC outputs across mixed domains"
```

### Task 4: Present all networks on one shared design board

**Files:**
- Modify: `apps/electrosim/lib/electrical_project_workspace_page.dart`
- Modify: `apps/electrosim/lib/f18_workspace_page.dart`
- Modify: `apps/electrosim/lib/runtime/electrosim_layout_persistence.dart`
- Create: `apps/electrosim/lib/mixed_board_projection.dart`
- Test: `apps/electrosim/test/electrical_project_workspace_test.dart`
- Test: `apps/electrosim/test/mixed_board_projection_test.dart`

**Interfaces:**
- Consumes the mixed `ElectricalProject` and per-network runtime snapshots.
- Produces one shared `CircuitVisualLayout` keyed by namespaced board element and connection IDs and one board projection that renders elements from all networks simultaneously.
- Project edits route each created component/source and connection to its homogeneous network; cross-domain wires are rejected before changing the project.
- Produces `MixedBoardProjection.fromProject(ElectricalProject)`, carrying a render-only aggregate circuit, namespaced board IDs for cross-network ID collision safety, and maps from board component/source/connection IDs back to `(networkId, localId)`; the aggregate must never be sent to a solver.

- [ ] **Step 1: Write failing shared-board widget tests**

Add tests that `mixedModeShowsEveryDomainOnOneBoard`, that duplicate local IDs across two networks remain distinct on the board and map back to their original network/local IDs, that a component added from the CC palette appears beside existing AC3 components without changing its stored ID, that both domain layers use the same persisted positions map, and that attempted cross-domain wire creation produces a visible rejection while preserving the prior circuit.

- [ ] **Step 2: Run the focused workspace tests and verify failure**

Run: `flutter test test/electrical_project_workspace_test.dart` from `apps/electrosim`.
Expected: current UI shows one selected network at a time and uses layouts keyed by network.

- [ ] **Step 3: Implement the unified mixed board projection**

Render a combined board projection in one `F18WorkspacePage`/canvas surface while retaining homogeneous network ownership in `ElectricalProject`. Keep editing callbacks domain-aware so component/source placement is routed to one network and connections can only reference terminals in that network. Show the active domain in palette/property controls without hiding placed components from the other domains.

- [ ] **Step 4: Share positions, routes, and layer state**

Replace the per-network-only layout map for mixed projects with one project-level layout keyed by namespaced board element/connection IDs. Continue reading old per-network layouts by mapping each legacy board's bounding box into deterministic non-overlapping slots in a 2x2 board grid, preserving relative positions and wire routes within each domain, then write the new shared layout for mixed documents. Keep original network-local electrical IDs unchanged in saved circuits.

- [ ] **Step 5: Run widget and persistence layout tests**

Run: `flutter test test/electrical_project_workspace_test.dart` and `flutter test test/postv2_p2_layout_persistence_test.dart` from `apps/electrosim`.
Expected: both domain networks render at once and mixed layout operations round-trip.

- [ ] **Step 6: Commit the shared board**

```bash
git add apps/electrosim/lib/electrical_project_workspace_page.dart apps/electrosim/lib/f18_workspace_page.dart apps/electrosim/lib/runtime/electrosim_layout_persistence.dart apps/electrosim/lib/mixed_board_projection.dart apps/electrosim/test/electrical_project_workspace_test.dart apps/electrosim/test/mixed_board_projection_test.dart
git commit -m "feat: show mixed networks on one board"
```

### Task 5: Add Mixed mode routing, global palette, and old-project migration

**Files:**
- Modify: `apps/electrosim/lib/main.dart`
- Modify: `apps/electrosim/lib/f18_workspace_page.dart`
- Modify: `apps/electrosim/lib/f18_g7_property_presenter.dart`
- Modify: `apps/electrosim/lib/f18_product_library_pages.dart`
- Modify: `apps/electrosim/lib/student_web_main.dart`
- Modify: `apps/electrosim/lib/runtime/electrosim_tp_session_controller.dart`
- Modify: `apps/electrosim/lib/f9_component_palette.dart`
- Modify: `apps/electrosim/lib/electrical_project_workspace_page.dart`
- Modify: `packages/electrosim_multiphysics/lib/src/electrical_project.dart`
- Test: `apps/electrosim/test/electrical_project_workspace_test.dart`
- Test: `apps/electrosim/test/f17_persistence_test.dart`

**Interfaces:**
- Consumes the board projection and shared layout from Task 4.
- Produces the user mode route `ElectricalMode.mixed`, opened as an `ElectricalProjectWorkspacePage`; palette filtering for mixed mode returns definitions from all four domains and tags every placement with its target homogeneous network.
- Produces mixed-palette entries with an explicit `placementMode`; a definition supported in multiple modes produces one entry per mode so placement never guesses a domain.

- [ ] **Step 1: Write failing mode/palette/migration tests**

Add a mode-menu test for the Mixed option and routing through the main app, a palette test that CC, AC, AC3, and PV entries are discoverable in Mixed mode with an explicit target domain, and migration tests for the existing two-network layout and relay/signal links to preserve components, connections, layout positions, link behavior, and IDs.

- [ ] **Step 2: Run focused UI/persistence tests and verify failure**

Run: `flutter test test/electrical_project_workspace_test.dart` and `flutter test test/f17_persistence_test.dart` from `apps/electrosim`.
Expected: Mixed selector/palette and shared-layout migration assertions fail before implementation.

- [ ] **Step 3: Route Mixed mode without constructing a solver circuit in mixed mode**

Add the Mixed choice to the toolbar/menu and route it from `F18WorkspacePage` through `main.dart` to `ElectricalProjectWorkspacePage` initialized by `ElectricalProject.emptyMixedBoard()`. Continue routing CC/AC/AC3/PV to existing single-domain workspaces. Ensure changing mode does not destroy current content; creating a mixed board from a populated circuit places that original circuit into its matching domain. Update each exhaustive `ElectricalMode` switch in the listed mode presenter, catalog filter, web entrypoint, TP router, and main workspace: Mixed routes to the project board or returns an explicit unsupported-context message; it is never sent to a domain solver or TP evaluator.

- [ ] **Step 4: Expose the four-domain catalog and preserve IDs**

Teach `F9ComponentPalette` to expose definitions from every domain only in mixed mode. Give each mixed-palette entry an explicit `placementMode`; duplicate a definition supported by multiple modes into one entry per supported mode. When adding an entry, route it to that homogeneous network and allocate a stable local ID; never relabel an existing component as another domain to make placement succeed.

- [ ] **Step 5: Migrate and persist old mixed projects**

Decode the prior schema with defaults for the new fields, merge old per-network layouts into the shared board layout, preserve legacy relay/signal links, and write the new versioned project representation. Keep old schemas readable.

- [ ] **Step 6: Run selector, palette, migration, and persistence tests**

Run: `flutter test test/electrical_project_workspace_test.dart`, `flutter test test/f17_persistence_test.dart`, and `flutter test test/m3b_palette_canonical_models_test.dart` from `apps/electrosim`.
Expected: all existing single-mode palette/persistence tests and new mixed-mode tests pass.

- [ ] **Step 7: Commit mode routing and migration**

```bash
git add apps/electrosim/lib/main.dart apps/electrosim/lib/f18_workspace_page.dart apps/electrosim/lib/f18_g7_property_presenter.dart apps/electrosim/lib/f18_product_library_pages.dart apps/electrosim/lib/student_web_main.dart apps/electrosim/lib/runtime/electrosim_tp_session_controller.dart apps/electrosim/lib/f9_component_palette.dart apps/electrosim/lib/electrical_project_workspace_page.dart packages/electrosim_multiphysics/lib/src/electrical_project.dart apps/electrosim/test/electrical_project_workspace_test.dart apps/electrosim/test/f17_persistence_test.dart
git commit -m "feat: add mixed design mode and migration"
```

### Task 6: End-to-end qualification of mixed design flows

**Files:**
- Modify: `apps/electrosim/test/electrical_project_workspace_test.dart`
- Modify: `apps/electrosim/test/electrical_project_runtime_test.dart`
- Modify: `apps/electrosim/test/f17_persistence_test.dart`

- [ ] **Step 1: Add the complete command-station-to-motor workflow test**

Create one mixed board containing a 24 V DC source, PLC Ladder (`I0` → `Q0`), one AC3 source, one PLC-linked contactor and one AC3 motor/load. Assert all devices are visible on the common board, Q0 closes the power contactor and load current appears, stopping Q0 opens it, the AC3 result is solved, and diagnostics identify domain-specific failures.

- [ ] **Step 2: Add the PV-to-AC workflow and compatibility tests**

Use a PV array and existing inverter with an AC load; assert both domain snapshots and conversion state are present. Round-trip the mixed board and verify component IDs, wire endpoints, links, positions, and runtime defaults. Load existing standalone DC, AC1, AC3, PV, and schema-v1 project fixtures and assert their previous solver kind and stable component/wire identity.

- [ ] **Step 3: Run the full targeted verification set**

Run `dart test` from each of `packages/electrosim_domain`, `packages/electrosim_multiphysics`, `packages/electrosim_controls`, and `packages/electrosim_pv`, then run `flutter test` and `flutter analyze` from `apps/electrosim`. Expected: all package/app tests pass, analysis has no errors, no mixed board is passed to a domain solver, and valid workflows have no project-level link/coupling errors or error-severity solver diagnostics.

- [ ] **Step 4: Review the final diff and commit qualification tests**

Run `git diff --check` and inspect the staged diff to confirm no unrelated working-tree edits are included, then commit only the mixed-mode integration tests.

```bash
git add apps/electrosim/test/electrical_project_workspace_test.dart apps/electrosim/test/electrical_project_runtime_test.dart apps/electrosim/test/f17_persistence_test.dart
git commit -m "test: qualify mixed electrical workflows"
```

## Coverage Review

- The project-model task covers up to four homogeneous networks and typed, validated links.
- The runtime task covers every present specialist solver and one shared simulation tick.
- The coupling task covers direct PLC actuation, AC1/AC3, safety arbitration, and PV conversion boundaries.
- The board task covers simultaneous display, editing/routing, domain-safe wires, shared placement, and layout migration.
- The mode/persistence task covers user discoverability, old project compatibility, component IDs, and old relay/signal links.
- End-to-end qualification covers mixed DC/PLC/AC3/motor and PV/inverter/AC workflows.
- The converter-coupling test pins the iteration ceiling and safe-open behavior when the PV/AC power exchange does not converge.
