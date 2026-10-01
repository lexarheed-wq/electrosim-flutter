# F18-G2 Execution Ledger

Base: `f18-g2a-wire-routing@d578c6598dddf0e08f99ce03b79e731ec36a687f`

## Intent

Replace generic first-level routing into the simulator with the approved F18 product hierarchy:
- Home
- Maintenance Center
- Design Center
- Session Shell / Dashboard
- explicit transition to the simulator only after selecting an activity.

## TDD evidence

Initial RED run `36925387666`:
- 0/7 navigation tests passed;
- expected failures were absence of real Maintenance/Design/Session intermediate destinations.

Implementation milestones:
- explicit center and session shell introduced;
- first navigation GREEN reached 8/8;
- compact center/session headers corrected after real overflow findings;
- approved G1 Home composition implemented in Flutter;
- invalid unbounded `Spacer` in scrollable Home cards removed;
- Home structural tests added for 1440/820/390;
- F9 functional navigation expectations migrated to G2 hierarchy;
- LAN secondary join test made viewport-aware.

## Final code-head qualification

Dedicated run `36927383762` on `8b730a2eef7e7616985e8d43d04de4c9ed75f1f8`:
- analyze: PASS;
- G2 tests: 11 PASS;
- application non-golden regressions: 83 PASS;
- historical visual baselines: preserved;
- non-UI protected package scope: PASS;
- `F18_G2_SHELL_NAVIGATION_GATE_PASS` emitted.

## Historical workflow ruling

Legacy F0/F1 still flag post-F0 scenario package content. Legacy F8 still applies an F15/F14 freeze. These inherited historical gates do not identify G2-introduced changes and are not modified to manufacture a green result.

## Merge ruling

No merge into `main` is performed automatically. Integration remains an explicit decision after exact-head qualification.
