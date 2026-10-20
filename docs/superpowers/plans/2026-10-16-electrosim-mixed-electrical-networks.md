# ElectroSim Mixed AC3 and 24 V Control Networks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Simulate one motor-control project with separate, electrically solved AC3 power and 24 V DC control networks connected through a physically solved DC relay coil and an AC3 dry contact.

**Architecture:** Keep `CircuitState.mode` homogeneous and add a versioned project containing named `CircuitState` networks and typed cross-network relay links. A project runtime coordinator advances both existing solvers on one clock, runs the PLC scan from solved DC input voltages, projects PLC output branches into DC, and transfers only the solved DC relay state to the linked AC3 contact.

**Tech Stack:** Dart 3.10.9, Flutter 3.38.10, existing `electrosim_domain`, `electrosim_multiphysics`, `electrosim_solver_dc`, `electrosim_solver_ac`, `electrosim_controls`, `electrosim_storage`, and `apps/electrosim` runtime/workspace.

**Spec:** `docs/superpowers/specs/2026-10-16-electrosim-mixed-electrical-networks-design.md`

## Global Constraints

- Every `CircuitState` remains homogeneous and is passed only to its matching existing solver.
- First release supports exactly one AC3 power network and one DC control network; AC1/PV cross-domain conversion is out of scope.
- The control network uses an explicitly drawn and solved 24 V DC source; a 230/24 V transformer/rectifier converter is a later phase.
- The contactor AC3 coil only actuates from its solved AC3 voltage; PLC Q never bypasses that coil.
- Cross-network relay bridges connect one `plc_dc` Q address, one DC `relay_coil` and one AC3 `contactor_aux_no`/`contactor_aux_nc`; feedback links connect an AC3 auxiliary contact to one `plc_dc` I address. Each endpoint is linked at most once.
- Legacy `CircuitState` and `SavedCircuitDocument` JSON remain readable and unchanged; lossy export of a multi-network project is rejected.
- A runtime tick integrates elapsed time once; any correction solve in that tick uses zero elapsed time.
- Ladder validation failure, disabled PLC, or control-supply loss forces Q outputs low and lets solved coil voltage determine physical release.
- Do not claim Dart analysis, tests, or a Mac build passed unless that command exits successfully.

## Review Focus

- Floating or disconnected PLC input: test that it reads false and raises an input diagnostic.
- Loss of the 24 V source after Q was on: test that the relay DC coil and linked AC3 contact release by the next composite tick.
- Q on with no AC3 voltage at the contactor coil: test that the AC3 contactor remains released.
- Dangling, duplicate, reversed-mode, or duplicate bridge endpoints: test project construction rejects each invalid reference.
- Legacy save opened as a one-network project then exported: test the original JSON remains semantically unchanged; exporting a project with two networks must fail explicitly.

---

### Task 1: Add the versioned electrical project domain

**Files:**
- Create: `packages/electrosim_multiphysics/lib/src/electrical_project.dart`
- Modify: `packages/electrosim_multiphysics/lib/electrosim_multiphysics.dart`
- Test: `packages/electrosim_multiphysics/test/electrical_project_test.dart`

**Interfaces:**
- Produces `ElectricalNetwork({required String id, required CircuitState circuit})`.
- Produces `CrossNetworkRelayLink({required String id, required String plcNetworkId, required String plcComponentId, required String outputAddress, required String dcNetworkId, required String relayCoilId, required String ac3NetworkId, required String ac3ContactId})`.
- Produces `CrossNetworkSignalLink({required String id, required String ac3NetworkId, required String auxiliaryContactId, required String dcNetworkId, required String plcComponentId, required String inputAddress})`.
- Produces immutable `ElectricalProject({required List<ElectricalNetwork> networks, List<CrossNetworkRelayLink> relayLinks = const [], List<CrossNetworkSignalLink> signalLinks = const []})`, `toJson()`, `toJsonString()`, and matching `fromJson` factories.
- `ElectricalProject` validates the phase-A supported shape: exactly one DC and one AC3 network; relay links resolve from `plc_dc` Q0–Q3 through a DC `relay_coil` to an AC3 `contactor_aux_no`/`contactor_aux_nc`; feedback links resolve from an AC3 auxiliary contact to a DC `plc_dc` I0–I3; no PLC address or physical endpoint is ambiguously linked.

- [ ] **Step 1: Write failing domain tests** named `roundTripsTwoHomogeneousNetworksAndCrossLinks`, `rejectsWrongModeOrDanglingRelayLinks`, `rejectsDuplicateBridgeEndpoints`, `rejectsInvalidPlcAddressesAndFeedback`, and `allowsSingleNetworkLegacyEnvelope`.
- [ ] **Step 2: Run `dart test test/electrical_project_test.dart` from `packages/electrosim_multiphysics`; confirm the missing API fails.**
- [ ] **Step 3: Implement immutable network, bridge, JSON codec, and validation in `electrical_project.dart`; export the public types.**
- [ ] **Step 4: Run the package test and `dart analyze` from `packages/electrosim_multiphysics`; all tests pass without changing `MultiphysicsProject`.**
- [ ] **Step 5: Commit only the domain files and test with `feat: add mixed electrical project contract`.**

### Task 2: Add a DC PLC model and reusable Ladder scan

**Files:**
- Modify: `packages/electrosim_domain/lib/src/electrical_types.dart`
- Modify: `packages/electrosim_domain/lib/src/component_model_contract.dart`
- Modify: `packages/electrosim_domain/lib/src/component_physics_contract.dart`
- Modify: `packages/electrosim_solver_dc/lib/src/solver_dc.dart`
- Create: `packages/electrosim_controls/lib/src/ladder_program_engine.dart`
- Modify: `packages/electrosim_controls/lib/electrosim_controls.dart`
- Test: `packages/electrosim_domain/test/plc_dc_contract_test.dart`
- Test: `packages/electrosim_solver_dc/test/plc_dc_io_test.dart`
- Test: `packages/electrosim_controls/test/ladder_program_engine_test.dart`

**Interfaces:**
- Adds `ElectricalBranchRole.plcOutput` and `ComponentElectricalLaw.programmableController`; model `plc_dc` has 10 terminals: `L+`, `M`, `I0`–`I3`, `Q0`–`Q3`; four controlled output branches connect terminal 0 (`L+`) to terminals 6–9 (`Q0`–`Q3`).
- Adds `LadderProgramEngine.scan({required List<Map<String,Object?>> program, required Map<String,bool> inputs, required LadderRuntimeState previous, required Duration elapsed}) -> LadderScanResult`.
- `LadderRuntimeState` holds Q0–Q3, M0–M15, T0–T15 accumulated seconds and DN bits; `LadderScanResult` exposes next state plus `programError`.
- Ladder grammar is exactly contact_no/contact_nc, TON, timer_done, coil/coil_set/coil_reset; addresses are I0–I3, Q0–Q3, M0–M15, T0–T15; TON preset is `(0, 3600]` seconds; at most one terminal output instruction per rung and it must be last.
- DC PLC output branches conduct only when the projected Q state is true and measured `L+`-to-`M` supply voltage is in `[20.4, 28.8]` V; PLC sense inputs have no conductive branch and are measured as terminal voltage relative to M after a solved DC step. An input reads true at or above 15.0 V, false at or below 5.0 V, and false with a diagnostic in between or while floating.

- [ ] **Step 1: Write failing model and solver tests** asserting four Q branches, isolated input pins, Q-open/Q-closed node voltage behavior, 20.4/28.8 V supply boundaries, 15/5 V input boundaries, and nominal 24 V output under load.
- [ ] **Step 2: Write failing Ladder tests** for NO/NC, SET/RESET holding, TON across scans, DN reset, malformed addresses/programs, and zero elapsed correction scans.
- [ ] **Step 3: Run the three focused tests** and confirm the new contract/engine behavior is missing.
- [ ] **Step 4: Add the `plcOutput` branch role, `programmableController` electrical law, `plc_dc` structural/physics contracts, and exhaustive inert handling in AC1/AC3; add a dedicated DC compile path for four controlled branches and omit isolated sense terminals from current paths.**
- [ ] **Step 5: Implement `LadderProgramEngine.scan` as a pure deterministic function; invalid programs return all Q false and preserve no energized output.**
- [ ] **Step 6: Run the domain, solver, and controls test files plus `dart analyze` for those packages.**
- [ ] **Step 7: Commit the PLC model, solver, Ladder engine, and tests with `feat: simulate DC PLC inputs outputs and Ladder`.**

### Task 3: Coordinate the DC and AC3 runtime

**Files:**
- Create: `apps/electrosim/lib/runtime/electrical_project_runtime_engine.dart`
- Modify: `apps/electrosim/lib/runtime/electrosim_runtime_engine.dart`
- Modify: `packages/electrosim_controls/lib/src/electromechanical_control_engine.dart`
- Test: `apps/electrosim/test/electrical_project_runtime_test.dart`

**Interfaces:**
- Produces immutable `ElectricalProjectRuntimeSnapshot` with `Map<String, ElectroSimRuntimeSnapshot> networks`, relay bridge states, feedback signal states, elapsed project time, and project diagnostics.
- Produces `ElectricalProjectRuntimeEngine.advance(ElectricalProject project, {required Duration elapsed, ElectricalProjectRuntimeSnapshot? previous})`.
- A tick performs: DC solve from previous Q; input threshold evaluation from solved `I`-to-`M` terminal voltages; one Ladder scan with elapsed time; zero-time DC correction solve with new Q; relay coil actuation from actual corrected DC coil voltage; AC3 projection of linked auxiliary contacts from the DC relay state; one AC3 solve; publish next feedback state.
- Cross-network relay-contact and auxiliary-feedback projection are explicit runtime states, never authored cross-network `Connection`s; a valid link must not create a false missing-local-relay warning.

- [ ] **Step 1: Write failing end-to-end fixture tests** for 24 V source → physical sensor → PLC I → Ladder Q → solved DC relay coil → linked AC3 dry contact → AC3 contactor coil → AC3 auxiliary feedback → PLC I; assert each stage’s physical result.
- [ ] **Step 2: Add failure tests** for open DC wire, supply loss after Q=true, floating input, missing AC3 coil voltage, and one-tick auxiliary feedback causality.
- [ ] **Step 3: Run `flutter test test/electrical_project_runtime_test.dart` from `apps/electrosim`; confirm coordinator behavior is absent.**
- [ ] **Step 4: Implement project scan coordinator using existing `ElectroSimRuntimeEngine` instances; do not integrate elapsed time twice.**
- [ ] **Step 5: Add explicit external linked-contact projection in the electromechanical control engine, preserving same-circuit link behavior and diagnostics.**
- [ ] **Step 6: Run project runtime tests and existing DC, AC3, relay, and contactor regression files; run app `flutter analyze`.**
- [ ] **Step 7: Commit the coordinator and regressions with `feat: couple DC relay controls to AC3 networks`.**

### Task 4: Persist composite projects without changing legacy saves

**Files:**
- Create: `packages/electrosim_storage/lib/src/electrical_project_storage.dart`
- Modify: `packages/electrosim_storage/lib/electrosim_storage.dart`
- Test: `packages/electrosim_storage/test/electrical_project_storage_test.dart`

**Interfaces:**
- Produces `SavedElectricalProjectDocument` with a new `formatName = 'electrosim-electrical-project'`, its own schema version, `ElectricalProject project`, and original save metadata.
- `SavedElectricalProjectDocument.fromJson` accepts the new envelope and wraps a `SavedCircuitDocument` as a single-network project; it never modifies `SavedCircuitDocument.currentSchemaVersion` or its decoder.
- `toLegacyElectricalJson()` succeeds only for one network with no cross-network links; otherwise throws `FormatException` naming the data that would be lost.

- [ ] **Step 1: Write failing tests** for composite JSON round trip, v0/v1/v2 legacy wrapping, unsupported future schema, and refusal of lossy export.
- [ ] **Step 2: Run `dart test test/electrical_project_storage_test.dart` from `packages/electrosim_storage`; confirm missing API fails.**
- [ ] **Step 3: Implement the versioned wrapper and exports while leaving existing storage classes unchanged.**
- [ ] **Step 4: Run storage project tests and all existing `multiphysics_storage_test.dart` / `f17_persistence_test.dart` regressions.**
- [ ] **Step 5: Commit storage changes with `feat: persist mixed electrical projects losslessly`.**

### Task 5: Add the composite workspace and cross-network link editor

**Files:**
- Create: `apps/electrosim/lib/electrical_project_workspace_page.dart`
- Modify: `apps/electrosim/lib/f18_workspace_page.dart`
- Modify: `apps/electrosim/lib/f9_component_palette.dart`
- Modify: `apps/electrosim/lib/f9_context_panels.dart`
- Modify: the existing app route that opens `F18WorkspacePage` (locate in `apps/electrosim/lib/` during implementation and replace only the composite-project entry route).
- Test: `apps/electrosim/test/electrical_project_workspace_test.dart`

**Interfaces:**
- `ElectricalProjectWorkspacePage({required ElectricalProject initialProject, required ValueChanged<ElectricalProject> onProjectChanged, ...})` owns one project simulation controller and the selected network ID.
- Network selector labels are exactly `Commande 24 V CC` and `Puissance AC3`; selection changes the active canvas/palette without copying components between circuits.
- Palette filters on the selected network’s `ElectricalMode`; the composite project editor exposes bridge creation by choosing one DC `relay_coil` and one AC3 auxiliary NO/NC contact.
- The runtime toolbar starts/pauses/advances the composite runtime as one clock, not two independent `ElectroSimSimulationController` clocks.
- `F18WorkspacePage` gains a controlled-network change callback so edits, undo/redo, direct device actuation and wire mutations update the canonical composite project.

- [ ] **Step 1: Write widget tests** for both network tabs, mode-filtered palette, creating/removing a relay bridge, synchronized start/pause, and status per network.
- [ ] **Step 2: Run `flutter test test/electrical_project_workspace_test.dart`; confirm the composite page is not present.**
- [ ] **Step 3: Add the page and controlled `F18WorkspacePage` callback; keep each underlying circuit editor bound to one `CircuitState`.**
- [ ] **Step 4: Wire project persistence and route entry; ensure a legacy saved circuit still enters the existing single-circuit workspace.**
- [ ] **Step 5: Run composite workspace tests and existing workspace navigation, palette, and persistence tests.**
- [ ] **Step 6: Commit UI integration with `feat: add mixed electrical project workspace`.**

### Task 6: Qualify end-to-end behavior and document delivery limits

**Files:**
- Modify: `apps/electrosim/test/ac3_timer_plc_component_test.dart`
- Create: `apps/electrosim/test/mixed_ac3_dc_motor_start_stop_test.dart`
- Create: `docs/f18/mixed-electrical/F18_MIXED_ELECTRICAL_REPORT.md`
- Modify: relevant release qualification workflow after identifying the repository’s active candidate workflow.

- [ ] **Step 1: Write the complete start/stop scenario** with STOP NC, START NO, overload NC, K1 self-hold through an AC3 auxiliary, DC relay bridge, motor contactor coil, and source-loss fault.
- [ ] **Step 2: Run the full focused regression set** for Ladder, project storage, mixed runtime, AC3 motor self-hold, DC solver, and workspace.
- [ ] **Step 3: Run `flutter analyze`, `flutter test`, `git diff --check`, and the active Mac Intel release workflow/build.**
- [ ] **Step 4: Record exact toolchain, commands, results, commit SHA, and any failed/unavailable physical validation in `F18_MIXED_ELECTRICAL_REPORT.md`.**
- [ ] **Step 5: Produce a Mac candidate only after analysis/tests/build pass; otherwise leave a clearly labeled source candidate and report the blocker.**

## Plan Self-Review

- Spec coverage: project contract and validation → Task 1; PLC and scan semantics → Task 2; shared clock, safety, relay coupling and diagnostics → Task 3; versioned persistence and legacy compatibility → Task 4; two-network workspace, palette and bridge management → Task 5; physical start/stop and candidate qualification → Task 6.
- Type consistency: Tasks 1–3 consistently use `ElectricalProject`, `ElectricalNetwork`, `CrossNetworkRelayLink`, `CrossNetworkSignalLink`, `LadderRuntimeState`, `LadderScanResult`, and `ElectricalProjectRuntimeSnapshot`.
- Review-focus risks have explicit tests in Tasks 1, 2, 3 and 4.
- The three domains and UI are sequentially dependent; implementation should use the native execution method in one worktree so interfaces remain consistent, with a full review after Task 6.
- A separate 230/24 V AC transformer plus rectifier/regulator is deliberately outside this plan, as fixed in the approved specification.
