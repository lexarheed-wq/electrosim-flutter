# ElectroSim F18-G3 — Session & Dashboard Operational Design

## Goal

Turn the qualified G2 session shell into a real teacher-session coordinator without routing session management or supervision through the simulator.

## Single authority

One `ElectroSimTpSessionController` is created per teacher session shell and remains authoritative for:
- Manage Session;
- Wiring workspace;
- Troubleshooting workspace;
- Supervision;
- LAN host synchronization.

No child destination may silently create a second TP controller for the same active teacher session.

## Manage Session

The F18 shell reuses the qualified `F17TpSessionDialog`:
- create TP;
- publish TP;
- teacher evaluation;
- close TP;
- local LAN sharing;
- address + six-character session code.

The dialog is opened from the session shell and from session workspaces through the same coordinator callback.

## Supervision

Supervision is a dedicated non-simulator page using the qualified `F17TpSupervisionPanel`.
It observes the same authoritative controller used by Manage Session and the workspaces.

## Workspace handoff

Opening Wiring or Troubleshooting from the dashboard:
- passes the same TP controller into `F9WorkspaceDemoPage`;
- preserves session navigation;
- overrides Dashboard to return to the F18 session shell;
- overrides Manage Session to invoke the coordinator-owned dialog.

## LAN ownership

The coordinator owns at most one `ElectroSimLanSyncHost`:
- generated code remains stable while the coordinator lives;
- repeated Manage Session opens reuse the current host info;
- disposing the coordinator closes the host.

## Invariants

- Manage/Supervision do not mount `SimulatorCanvas`.
- Wiring/Troubleshooting may mount the simulator only after explicit dashboard selection.
- TP lifecycle observed in Supervision equals the lifecycle changed in Manage Session.
- Workspace session controls operate on the same controller.
- G3 does not modify solver/domain/Canvas/TP engine packages.

## Gate marker

`F18_G3_SESSION_DASHBOARD_GATE_PASS`
