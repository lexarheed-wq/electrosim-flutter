# AC3 Motor Control and VFD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a usable AC3 motor-control simulation for direct start, reversing, star-delta and variable speed, including protection behavior, mechanical inertia and persisted examples.

**Architecture:** Extend existing AC3 component contracts and protection coordinator for thermal auxiliaries and mechanical interlocking. Add a deterministic induction-motor mechanical state to the runtime while retaining the present electrical impedance solver for backward compatibility. Model a VFD as an explicit boundary between independently solved input-grid and output-motor AC3 networks in the existing `ElectricalProject` framework; never apply its frequency to the upstream grid. Integrate the behavior into the component palette, properties, project persistence and example circuits.

**Tech Stack:** Dart 3.10.9, Flutter 3.38.10, `electrosim_domain`, `electrosim_solver_ac`, `electrosim_protection`, `electrosim_controls`, `electrosim_multiphysics`, `electrosim_storage`, and `apps/electrosim`.

**Spec:** `docs/superpowers/specs/2026-10-16-ac3-motor-control-design.md`

## Global Constraints

- Keep legacy single-circuit AC3 solve and save behavior readable and stable; absent new motor parameters use documented defaults and report which values are assumed.
- Motor mechanics are deterministic and bounded: speed is signed, acceleration depends on torque, inertia, frequency, voltage and load; de-energized motors coast down; reversal passes through zero.
- The AC3 electrical solver retains its present single-frequency-per-network contract. A VFD is the only bridge between the fixed-frequency input network and variable-frequency output network.
- Interlocked forward/reverse and star/delta contactors must fail open under simultaneous requests. No PLC or UI projection may bypass physical contactor coils, protection trips or interlocks.
- Thermal trip opens power poles and 95–96, closes 97–98 and remains latched until explicit reset.
- A VFD control fault, invalid frequency/ramp, missing input supply, overcurrent or overload has a safe output state and actionable diagnostic.
- Do not stage or overwrite unrelated pre-existing working-tree changes. Commit only the files named for the task being completed.
- Run implementation checks described below because simulation behavior changes. Do not report a command as passing unless its exit status confirms it.

## Review Focus

- Legacy AC3 documents with missing motor/VFD fields load with stable results and without pretending defaults were user-entered ratings.
- Thermal auxiliary contacts track the same latch as the overload poles through trip, cooling and manual reset.
- Reversing interlock remains safe for simultaneous coil requests, a welded/latched request, and either direction transition; reverse speed changes sign only after mechanical deceleration.
- Star and delta coils never conduct together, including timer reset, pause/resume, and zero-time correction solves.
- VFD input network frequency stays fixed while output frequency follows a bounded ramp; loss of input/control supply drops output safely.
- Project JSON round trips VFD boundary settings and both networks; legacy single-network save/export remains lossless.
- UI labels distinguish grid-side and motor-side values and surface invalid wiring/configuration near the affected device.

---

### Task 1: Add thermal auxiliary contacts and explicit overload reset

**Files:**
- Modify: `packages/electrosim_domain/lib/src/component_model_contract.dart`
- Modify: `packages/electrosim_domain/lib/src/component_physics_contract.dart`
- Modify: `packages/electrosim_protection/lib/src/protection_coordinator.dart`
- Test: `packages/electrosim_protection/test/protection_coordinator_test.dart`
- Test: `packages/electrosim_solver_ac/test/three_phase_physical_devices_test.dart`

**Interfaces:**
- Extend `thermal_overload_3p` with stable auxiliary terminals `95`, `96`, `97`, `98`, maintaining existing six power terminals and serialized model identity.
- Expose auxiliary state from the same `ProtectionRuntimeState` latch that controls the three power poles: 95–96 closed at rest/open on trip; 97–98 open at rest/closed on trip.
- Add an explicit reset operation to the protection coordinator that clears a latched overload only when its configured reset condition is satisfied; reset must not silently clear a live overload.

- [ ] **Step 1: Add failing tests** for terminal contract, normal/tripped pole states, both aux contact states, latched state across cooling, explicit reset, and reset rejected while overload remains active.
- [ ] **Step 2: Run the two focused Dart test files** and record the expected missing-contract/state failures.
- [ ] **Step 3: Implement the terminal/physics contracts and overload state transition; update exhaustive model handling without changing existing component IDs.**
- [ ] **Step 4: Run both focused test files and `dart analyze` in the affected packages.**
- [ ] **Step 5: Commit only these domain/protection files and tests as `feat: add overload auxiliary contacts and reset`.**

### Task 2: Add mechanical contactor interlock accessory

**Files:**
- Modify: `packages/electrosim_domain/lib/src/component_model_contract.dart`
- Modify: `packages/electrosim_controls/lib/src/electromechanical_control_engine.dart`
- Modify: `apps/electrosim/lib/f9_component_palette.dart`
- Modify: `apps/electrosim/lib/f9_context_panels.dart`
- Modify: `apps/electrosim/lib/f18_component_asset_visual.dart`
- Test: `packages/electrosim_controls/test/electromechanical_control_engine_test.dart`
- Test: `apps/electrosim/test/f18_control_modules_visual_test.dart`

**Interfaces:**
- Add an AC3 mechanical-interlock accessory with no electrical terminals and two explicit contactor references stored in its component parameters.
- Before contactor actuation is finalized for a tick, resolve all interlock pairs; if both linked contactors request closure, force both open and emit a stable diagnostic naming the accessory and pair.
- Missing, duplicate, self-referential or wrong-type references fail safely open and show a configuration diagnostic.

- [ ] **Step 1: Add failing engine tests** for either direction alone, simultaneous requests, invalid references, multiple interlocks and persistence of the safe-open result.
- [ ] **Step 2: Add failing palette/property/visual contract checks** for the accessory, its two references and zero-terminal visual placement.
- [ ] **Step 3: Run focused tests** and verify the accessory/engine support is absent.
- [ ] **Step 4: Implement the accessory contract, resolver and UI configuration; ensure wired NC auxiliaries remain independently effective.**
- [ ] **Step 5: Run focused engine and widget tests plus app/package analysis.**
- [ ] **Step 6: Commit only the interlock files/tests as `feat: add AC3 mechanical contactor interlock`.**

### Task 3: Add induction motor parameters and dynamic mechanical state

**Files:**
- Modify: `packages/electrosim_domain/lib/src/component_model_contract.dart`
- Modify: `packages/electrosim_domain/lib/src/component_physics_contract.dart`
- Modify: `packages/electrosim_solver_ac/lib/src/solver_ac3.dart`
- Modify: `apps/electrosim/lib/runtime/electrosim_runtime_engine.dart`
- Modify: `apps/electrosim/lib/runtime/rotor_motion.dart`
- Modify: `apps/electrosim/lib/f9_context_panels.dart`
- Test: `packages/electrosim_solver_ac/test/three_phase_physical_devices_test.dart`
- Test: `apps/electrosim/test/ac3_motor_mechanics_test.dart` (create)

**Interfaces:**
- Extend six-terminal AC3 motor parameters with pole pairs, rated frequency/voltage/power, rated speed, inertia and load torque; validate finite positive ranges and preserve stable defaults for old documents.
- Add per-motor runtime state for signed angular speed, acceleration and simulation time. Advance once per elapsed runtime tick using bounded deterministic torque/slip dynamics; use zero elapsed time for any protection correction solve.
- Keep present three-phase electrical impedance behavior as the steady-state electrical approximation; expose calculated electrical operating state separately from mechanical speed.
- Update property display and rotor animation to consume the mechanical state, distinguish synchronous-field speed from actual rotor speed, and retain sign/orientation through reversal.

- [ ] **Step 1: Add failing solver/runtime tests** for default legacy motor, invalid parameter diagnostics, rest-to-run acceleration, steady loaded speed below synchronous speed, increased load reducing speed, coast-down, reverse torque through zero, bounded large time steps and zero-elapsed correction.
- [ ] **Step 2: Run the focused AC3 and app motor tests** and record absent/incorrect dynamics.
- [ ] **Step 3: Add domain parameters and pure mechanical transition calculation; thread state through runtime snapshot and one-tick update.**
- [ ] **Step 4: Bind rotor animation and properties to actual signed speed while displaying assumed/default ratings clearly.**
- [ ] **Step 5: Run focused motor/AC3 runtime regressions and analyzer for affected packages/app.**
- [ ] **Step 6: Commit only motor model/runtime/UI files and tests as `feat: simulate AC3 motor inertia and load`.**

### Task 4: Enforce mutually exclusive star/delta and reversing behavior

**Files:**
- Modify: `packages/electrosim_controls/lib/src/electromechanical_control_engine.dart`
- Modify: `apps/electrosim/lib/runtime/electrosim_runtime_engine.dart`
- Modify: `apps/electrosim/lib/runtime/electrosim_simulation_controller.dart`
- Test: `packages/electrosim_controls/test/electromechanical_control_engine_test.dart`
- Test: `apps/electrosim/test/ac3_timer_plc_component_test.dart`
- Test: `apps/electrosim/test/ac3_motor_reversing_test.dart` (create)

**Interfaces:**
- Centralize safety arbitration for configured contactor groups: star/delta pair and forward/reverse pair use the same safe-open conflict result but distinct diagnostics.
- Star-to-delta sequence opens star, observes configured dead time, then closes delta; timer reset, stop, overload, pause/resume and competing requests cannot overlap contacts.
- Reversing command releases the active contactor before enabling the other; the dynamic motor model decelerates and changes sign only when torque and elapsed simulation time produce that transition.
- Existing hand-wired NC auxiliary interlocks and the new mechanical interlock compose; neither is bypassed by PLC output links.

- [ ] **Step 1: Add failing tests** for all transition edges, simultaneous commands, timer reset, trip during transition, pause/resume and electrical/mechanical interlock composition.
- [ ] **Step 2: Run the focused control, timer/PLC and reversing tests; capture the baseline behavior.**
- [ ] **Step 3: Implement arbitration and ordered transitions at the shared control/runtime boundary; preserve deterministic tick ordering.**
- [ ] **Step 4: Run the focused tests and existing contactor/timer/PLC regression set; analyze affected code.**
- [ ] **Step 5: Commit only control/runtime tests and implementation as `fix: interlock reversing and star delta contactors`.**

### Task 5: Add VFD domain contract and project boundary

**Files:**
- Modify: `packages/electrosim_multiphysics/lib/src/electrical_project.dart`
- Modify: `packages/electrosim_multiphysics/lib/electrosim_multiphysics.dart`
- Modify: `packages/electrosim_domain/lib/src/component_model_contract.dart`
- Modify: `packages/electrosim_domain/lib/src/component_physics_contract.dart`
- Test: `packages/electrosim_multiphysics/test/electrical_project_test.dart`
- Test: `packages/electrosim_solver_ac/test/three_phase_physical_devices_test.dart`

**Interfaces:**
- Add a typed `CrossNetworkVfdLink` associating one grid-side AC3 network and one motor-side AC3 network with one VFD component; extend `ElectricalProject` schema through a backward-compatible migration that still reads schema version 1 and legacy one-network circuits.
- Add a VFD component contract for grid input and motor output domains, frequency/ramp, base voltage/frequency, current and power limits, motor nominal data, command state, direction, fault and reset state.
- Validate exactly one VFD per boundary, correct network modes, component existence, no duplicate network/device endpoints, valid finite ranges, and reject unsupported mixed project shapes with action-specific diagnostics.

- [ ] **Step 1: Add failing project/contract tests** for VFD link round trip, schema migration, invalid networks/terminals/settings, duplicate endpoints and unchanged v1/legacy decoding.
- [ ] **Step 2: Run the focused domain/project tests and record the expected failures.**
- [ ] **Step 3: Implement the typed project link, migration and VFD parameter contract; keep the single-network project codec stable.**
- [ ] **Step 4: Run focused tests and `dart analyze` for domain and multiphysics packages.**
- [ ] **Step 5: Commit only domain/project contract and tests as `feat: define AC3 VFD project boundary`.**

### Task 6: Simulate VFD ramp, output limits and safe faults

**Files:**
- Create: `packages/electrosim_multiphysics/lib/src/vfd_runtime.dart`
- Modify: `packages/electrosim_multiphysics/lib/electrosim_multiphysics.dart`
- Modify: `apps/electrosim/lib/runtime/electrical_project_runtime_engine.dart`
- Modify: `apps/electrosim/lib/runtime/electrosim_runtime_engine.dart`
- Test: `packages/electrosim_multiphysics/test/vfd_runtime_test.dart` (create)
- Test: `apps/electrosim/test/electrical_project_runtime_test.dart`

**Interfaces:**
- Add a pure VFD state transition that ramps output frequency and voltage, enforces direction, base-frequency V/f law and above-base voltage limit, and reports current/power/thermal faults.
- The project runtime solves grid-side and motor-side AC3 networks at their respective frequencies on one shared elapsed-time clock. The input frequency remains the network nominal frequency; only the output network receives the VFD command.
- Trip or loss of grid/control supply forces output frequency/voltage and motor torque to the documented safe state; reset is explicit and only succeeds when reset conditions permit.
- Every runtime result exposes input/output frequency, commanded and actual motor speed, current/loading, ramp progress and a concrete fault/invalid-link diagnostic.

- [ ] **Step 1: Add failing pure-state and integration tests** for ramp-up/down, direction, base-frequency behavior, voltage ceiling, current/thermal trip, supply loss, invalid configuration, independent grid/output frequencies and single shared clock.
- [ ] **Step 2: Run focused tests** and confirm the project runtime does not yet impose separate frequencies.
- [ ] **Step 3: Implement the VFD state transition and runtime coordination; solve output at current ramp frequency without changing input network frequency.**
- [ ] **Step 4: Run project/VFD tests and existing project runtime/AC3 solver tests; run package/app analysis.**
- [ ] **Step 5: Commit only VFD runtime files and tests as `feat: simulate AC3 variable frequency drive`.**

### Task 7: Integrate AC3 palette, properties, persistence and examples

**Files:**
- Modify: `apps/electrosim/lib/f9_component_palette.dart`
- Modify: `apps/electrosim/lib/f9_context_panels.dart`
- Modify: `apps/electrosim/lib/f18_component_asset_visual.dart`
- Modify: `apps/electrosim/lib/industrial_workspace_representation.dart`
- Modify: `packages/electrosim_storage/lib/src/electrical_project_storage.dart`
- Modify: `apps/electrosim/lib/electrical_project_workspace_page.dart`
- Test: `apps/electrosim/test/ac3_motor_control_catalog_test.dart` (create)
- Test: `apps/electrosim/test/electrical_project_workspace_test.dart`
- Test: `apps/electrosim/test/f17_persistence_test.dart`

**Interfaces:**
- Add localized catalog entries, appropriate realistic assets/geometry, terminal names, editable parameters and state/fault panels for the mechanical interlock and VFD; expose overload auxiliary terminals in the terminal editor/visual.
- Add four built-in example projects: direct start with self-hold and overload; forward/reverse with both interlocks; star-delta with dead time; VFD with separate grid/motor networks and speed ramp.
- Save/reopen each example and retain old project and circuit documents. Validate project links and component references at edit time and after reload.
- Show grid-side frequency and VFD output frequency as distinct values; show actual rotor speed and load effects in the motor panel.

- [ ] **Step 1: Add failing catalog, widget, and persistence tests** for component discoverability, terminal/property editing, examples, save/reload and visible diagnostics.
- [ ] **Step 2: Run the focused app/storage tests and identify currently absent UI and serialization paths.**
- [ ] **Step 3: Implement palette/properties/visual integration, example project construction and project save/reload path.**
- [ ] **Step 4: Run focused tests plus existing palette, workspace and persistence regressions; run app/storage analysis.**
- [ ] **Step 5: Commit only app/storage integration files and tests as `feat: add AC3 motor control examples and controls`.**

### Task 8: End-to-end qualification and Mac candidate

**Files:**
- Create: `apps/electrosim/test/ac3_motor_control_end_to_end_test.dart`
- Create: `docs/f18/motor-control/AC3_MOTOR_CONTROL_QUALIFICATION.md`
- Modify: the existing Mac Intel candidate workflow only if qualification reveals it needs a targeted correction.

- [ ] **Step 1: Add end-to-end scenarios** for direct start/stop/overload reset, forward/reverse, star-delta transition, VFD ramp and grid/output frequency separation; assert safe behavior under simultaneous commands and supply loss.
- [ ] **Step 2: Run focused tests, then the relevant package/app regression suites.**
- [ ] **Step 3: Run `flutter analyze`, full `flutter test`, and `git diff --check`; inspect every failure before fixing or reporting it.**
- [ ] **Step 4: Run the configured Mac Intel candidate workflow and record exact revision, artifact, toolchain, commands, test/build status and remaining limitations in the qualification report.**
- [ ] **Step 5: Deliver a candidate only if qualification succeeds; otherwise deliver the source revision and exact CI blocker without calling it qualified.**

## Plan Self-Review

- Spec coverage: overload auxiliaries/manual reset → Task 1; mechanical interlock → Task 2; motor induction dynamics → Task 3; star-delta and reversal safety → Task 4; typed two-frequency VFD boundary → Task 5; ramp/limits/fault model → Task 6; UI, persistence and examples → Task 7; end-to-end qualification → Task 8.
- Backward compatibility is explicit in Tasks 1, 3, 5 and 7 and as a global constraint; VFD frequency is constrained to a separate AC3 network so the upstream grid cannot be altered.
- Safety review scenarios cover simultaneous/welded commands, live overload reset, source/control loss, project-link errors and zero-time correction solves.
- Implementation dependencies are sequential, so execute tasks in order in the current working tree and review each commit before continuing. Preserve unrelated dirty work by staging only listed paths.
