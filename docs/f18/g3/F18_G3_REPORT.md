# ElectroSim F18-G3 — Session & Dashboard Qualification Report

## Status

Qualification marker: `F18_G3_SESSION_DASHBOARD_GATE_PASS`

Qualified branch: `f18-g3-session-dashboard`  
Qualified code head before this report-only commit: `13509e0e10f7f701337edf5e005b14df7cc60b8e`

Dedicated qualification run: `36932771395`

## Operational session architecture

G3 turns the qualified G2 shell into a real teacher-session coordinator.

### Single session authority

`F18TeacherSessionCoordinatorPage` owns one authoritative
`ElectroSimTpSessionController` for the life of the teacher session.

The same controller is reused by:
- Manage Session;
- Wiring workspace;
- Troubleshooting workspace;
- Supervision;
- local LAN host synchronization.

Opening a child surface does not silently create a second TP session.

### Manage Session

The F18 session shell reuses the validated `F17TpSessionDialog` for:
- TP draft creation;
- publication;
- teacher evaluation;
- closing the TP;
- LAN teacher sharing;
- endpoint + six-character session code.

Manage Session is reachable both from the dashboard shell and from an active
session workspace through the same coordinator-owned callback.

### Supervision

Supervision is now a dedicated non-simulator surface using
`F17TpSupervisionPanel`.

It observes the same TP controller changed by Manage Session and by session
workspaces.

### Workspace handoff

Opening Wiring or Troubleshooting from the dashboard:
- explicitly mounts the simulator;
- receives the coordinator-owned TP controller;
- preserves session navigation;
- returns Dashboard to the F18 session shell;
- routes Manage Session to the coordinator-owned dialog.

The session state therefore survives Dashboard ↔ Workspace transitions.

### LAN ownership

The coordinator owns at most one `ElectroSimLanSyncHost`.

Repeated Manage Session opens reuse the current host information while the
coordinator remains alive. Coordinator disposal closes the LAN host.

The 1100 px intermediate-width overflow discovered by the G3 LAN test was
corrected by keeping the session header in dense navigation mode below
1200 px.

## Automated evidence

Dedicated run `36932771395` on code head
`13509e0e10f7f701337edf5e005b14df7cc60b8e`:

- Flutter/Dart locked toolchain: PASS
- application analyze: PASS
- G3 targeted session/dashboard tests: **4 PASS**
- application non-golden regression suite: **87 PASS**
- historical visual baselines preserved:
  `F18_G3_LEGACY_GOLDENS_PRESERVED`
- all package production scopes protected:
  `F18_G3_PROTECTED_SCOPE_PASS`
- final marker:
  `F18_G3_SESSION_DASHBOARD_GATE_PASS`

Targeted proofs include:
1. Manage Session and Supervision share one real TP controller.
2. Workspace reuses the session controller and Dashboard returns to the shell.
3. LAN teacher sharing works from the F18 shell without layout overflow.
4. Supervision does not route through `SimulatorCanvas`.

## Scope integrity

G3 production changes are restricted to `apps/electrosim/**`.

No production package under `packages/**` was changed relative to qualified
G2 head `1a533a0a256fd1b79ab133baff7492f52fd4ddb7`.

Therefore G3 does not rewrite:
- electrical domain/topology;
- DC/AC solvers;
- Canvas/routing engine;
- TP engine;
- LAN protocol;
- diagnostics/measurements;
- PV/energy;
- storage/scenarios.

## Historical workflows

Legacy F0/F1/F8 may remain red because they compare the modern F17/F18
repository against historical F0/F14 baselines. They are not altered or
suppressed to manufacture a green result.

G3 qualification is based on its exact phase-scope drift guard plus the full
application non-golden regression suite.

## Outcome

G3 Session & Dashboard is qualified.

This report-only commit must receive one final exact-head G3 workflow pass
before handoff or physical-test candidate preparation.

`F18_G3_SESSION_DASHBOARD_GATE_PASS`
