# ElectroSim F18-G2 — Shell & Navigation Design

## Goal

Replace the F17/F9 pattern where first-level product choices can route directly into the simulator with an explicit F18 information architecture.

## Required first-level routes

Home contains exactly three primary destinations:
1. Create a new session
2. Maintenance center
3. Design center

Joining an existing session remains a secondary action.

## Design center

The Design Center is a real landing surface, not a simulator alias.

Primary actions:
- Wiring
- Healthy schematic library

Selecting Wiring is the explicit transition into the simulator.

## Maintenance center

The Maintenance Center is a real landing surface.

Primary actions:
- Troubleshooting
- Fault library

Selecting Troubleshooting is the explicit transition into the simulator.

## Session shell

Creating a session opens the persistent session shell and dashboard, not the simulator.

Persistent navigation:
- Home
- Dashboard
- Manage session

Dashboard actions:
- Wiring
- Troubleshooting
- Supervision

Only Wiring or Troubleshooting enters the simulator. Supervision opens its own teacher supervision surface.

## Navigation invariants

- Each first-level action has a unique semantic destination.
- No generic fallback route silently redirects to the simulator.
- Back navigation preserves the expected product hierarchy.
- Compact/medium/expanded layouts expose the same information architecture.
- Navigation does not mutate CircuitState.
- Existing F17 runtime, TP, LAN and solver behavior is not rewritten in G2.

## Gate marker

`F18_G2_SHELL_NAVIGATION_GATE_PASS`
