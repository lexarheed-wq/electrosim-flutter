# ElectroSim — R6 qualification matrix (PNEU-DIR-001 v1.0)

Scope: **development qualification, not industrial functional-safety
certification**. This register is intentionally fail-closed. A green CI job for
one fixture cannot be substituted for an unevaluated requirement.

## Provenance and integration

- Target staging: `feat/g5-industrial-geometry-20261009`, never `main`.
- R0–R3/C, followed by R3/D–R5/B, were integrated through separately
  qualified PRs #79, #81, #83, #85, #86, #89, #87, #88, #91, #92.
- PR #95 develops the R6 harness; its final acceptance must refer to the
  exact *integrated G5 SHA after the merge*, not an ancestor or an isolated
  branch run.
- Every artifact: raw CI log, runner/CPU/SDK metadata, source SHA and unedited
  screenshot where applicable. Do not extrapolate Linux timings to macOS.
- The simulator is a generic pedagogical isothermal gas model, not manufacturer
  validation, a certified ISO 1219 symbol library, or machine-safety testing.

## Coverage inventory

| Director criterion | Current harness / evidence | R6 final disposition |
| --- | --- | --- |
| PHY-01 to PHY-07 | R2 gas/force/orifice/cylinder tests and R6 mass fixtures | Re-run full scientific suite on integrated SHA; PHY-07 timestep sensitivity requires explicit regression |
| CPL-01 | R3 real DC S1/K1/B1/5/2 and `test/r6_integration_cycle_test.dart` | Require proof of actual reached end-switch at physical time and no auto-rearm |
| CPL-02/03/04 | Solenoid delays, hysteresis, valve memory, supply isolation and fault suite | Verify single clock / no double advancement on integrated SHA |
| REG-01 | G5 complete runtime, canvas, web, TP and DC reference benchmark | Mandatory success; never disable when running R6 |
| REG-02/03 | Multiphysics project serialization and 30/100/200/400 two-view model | Require migration/version tests plus real history/roundtrip |
| UI-01 | Flutter R4 workshop widget and Chromium 10-component front/schematic screenshot | A gallery screenshot is not proof of full connection/edit journey |
| UI-02 | R4 original vector pictograms | **NOT YET ACCEPTED**: visual tige/tiroir animations must be driven from accepted physical snapshots, measured and reviewed |
| PERF-01 physical | `pneumatics-r6-physical-scale` Dart, real p50/p95, 2 warmups + 5 observations | Partial: 30/100/200/400 isothermal volumes connected, **not** 400 active cylinders |
| PERF-01 editor model | `pneumatics-r6-editor-model-scale` | Partial: ids/layouts and serialization, no GPU frame measurement |
| PERF-01 Flutter rendering | `pneumatics-r6-rendered-flutter-scale` on Linux + `pneumatics-r6-macos-flutter-render` on Intel Mac | Partial: tests construct both Flutter widget trees; not a 60 Hz sustained-frame proof |
| PERF-01 three scenarios | Electric-only / pneumatic active / electropneumatic mixed (30/100/200/400), each 10s warm-up + 60s × 3 | **NOT YET ACCEPTED**: existing microbench must not be represented as this gate |
| PERF-01 timing budgets | Connection p95 ≤100ms, ≥95% frames ≤16.7ms, simulated-vs-real ≤100ms drift, 400 mixed p95 ≤80ms/100ms simulated | **NOT YET ACCEPTED**: profile actual release engine/worker and browser/Intel Mac first |
| PERF-01 resource leaks | bounded requests, persistent native isolate and genuine Web worker, shutdown/reopen memory trend | **NOT YET ACCEPTED**: must verify workers and retained objects, not only process RSS |
| BUILD-01 | G5 Web production, Chromium browser, Intel Mac release candidate, Intel Mac physical bench and real Flutter widget tests | Require clean final-sha jobs, screenshot artifacts and startup proof; a mere successful binary build is not an interactive test |
| Schematic ISO 1219 | R3/C 5/2 mapping P=1, A=2, B=4, R=3, S=5 | Semantic mappings are present; **NOT CERTIFIED** as a compliant symbol library |

## Scientific performance fixture characteristics

- `30/100/200/400` *connected fixed-gas chambers* and
  `29/99/199/399` explicit calibrated passages. Isothermal air,
  finite positive chamber masses, immutable snapshots, 10 accepted 4-ms
  substeps per 40-ms simulated request. Runs are deterministic and retain
  signed floating-point total mass residuals.
- Each count has only 2 warm-up runs and 5 timed observations: a functional
  and microbenchmark gate, **not** the director's release-grade 60s × 3.
- The model-view test uses 30/100/200/400 pneumatic device identities without
  simulating their gas state. Widget test builds 30/100/200/400 actual Flutter
  tiles, and checks switching of platine/schéma; it does not measure GPU fps.
- Measurements must always be read from that run's JSON/log artifacts; never
  copy results between SHAs or claim broad hardware equivalence.

## Release decision

`R6_FINAL_PASS` can be emitted **only** when every required row above is
supported by a CI result or manually verified release-profile evidence on the
exact G5 integration SHA, with the numerical thresholds predeclared.

Before that the accurate state is **R6/A implemented and being qualified;
R6 overall not yet closed**. Keep the feature flag off for end users and
preserve the existing electrical circuit contract.
