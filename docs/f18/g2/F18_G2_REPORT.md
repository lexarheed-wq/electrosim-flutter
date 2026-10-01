# ElectroSim F18-G2 — Shell & Navigation Qualification Report

## Status

Qualification marker: `F18_G2_SHELL_NAVIGATION_GATE_PASS`

Qualified branch: `f18-g2-shell-navigation`  
Qualified code head before this report-only commit: `8b730a2eef7e7616985e8d43d04de4c9ed75f1f8`

Dedicated qualification run: `36927383762`

## Product architecture implemented

### Home
The F18 Home now follows the approved G1 visual direction and exposes exactly three primary product entries:
1. Create a new session
2. Maintenance Center
3. Design Center

Joining an existing LAN session is retained as a separate secondary action.

Responsive structure:
- expanded: three primary cards in one row;
- medium: two-column hierarchy;
- compact: single-column scrollable hierarchy;
- secondary join panel remains below primary actions.

### Design Center
The Design Center is a real landing surface. It no longer aliases directly to the simulator.

Primary actions:
- Wiring
- Healthy schematic library

Only Wiring enters the simulator.

### Maintenance Center
The Maintenance Center is a real landing surface.

Primary actions:
- Troubleshooting
- Fault library

Only Troubleshooting enters the simulator.

### Session Shell
Creating a session opens a dashboard shell before any simulator.

Persistent session navigation:
- Home
- Dashboard
- Manage session

Dashboard:
- Wiring
- Troubleshooting
- Supervision

Only Wiring/Troubleshooting enter the simulator.

### Responsive navigation
- compact (<600): compact icon navigation;
- medium (600–1000): dense icon navigation to avoid header overflow;
- expanded (>1000): full labelled navigation and session status.

Actions keep stable keys/tooltips for keyboard/semantic discoverability.

## Regression decisions

Two F9 shell expectations were intentionally migrated because G2 changes the product architecture:
- creating a session must no longer immediately mount `SimulatorCanvas`;
- entering Maintenance must no longer immediately mount the troubleshooting simulator.

The historical LAN home test was retained and adapted only to scroll the secondary Join Session action into view before tapping it. LAN behavior itself was not changed.

Historical F9 goldens were not regenerated or auto-accepted.

## Automated evidence

Run `36927383762` on code head `8b730a2eef7e7616985e8d43d04de4c9ed75f1f8`:

- Flutter/Dart locked toolchain: PASS
- application analyze: PASS
- G2 navigation/reference-size tests: **11 PASS**
- application non-golden regression suite: **83 PASS**
- historical visual baselines preserved: `F18_G2_LEGACY_GOLDENS_PRESERVED`
- protected non-UI package scope: `F18_G2_PROTECTED_SCOPE_PASS`
- final marker: `F18_G2_SHELL_NAVIGATION_GATE_PASS`

Reference viewport coverage:
- 1440×900
- 820×1180
- 390×844

## Scope integrity

G2 changes are restricted to:
- `apps/electrosim/**`
- documentation/workflows
- optionally `packages/electrosim_ui_kit/**` by gate policy (no non-UI package changes are allowed)

No G2 production modification is allowed in:
- domain/topology;
- DC/AC solvers;
- Canvas routing core;
- PV/energy;
- measurements/diagnostics;
- TP/storage/scenarios.

The dedicated G2 drift guard passed against G2A base
`d578c6598dddf0e08f99ce03b79e731ec36a687f`.

## Historical workflows

Legacy `f0`, `f1` and `f8` are not authoritative for G2:
- `f0/f1` still reject the post-F0 scenario package as `scenario-content-in-f0`;
- `f8` still applies `F15-F14-freeze` to the modern F17/G1/G2A/G2 tree.

These checks were not rewritten or suppressed. Their failures are documented as historical-baseline mismatch, while the F18 G2 gate performs exact phase-scope and regression checks.

## Outcome

G2 shell/navigation architecture is qualified on the code head above.  
The report-only commit must receive one final exact-head G2 workflow pass before handoff or merge consideration.

`F18_G2_SHELL_NAVIGATION_GATE_PASS`
