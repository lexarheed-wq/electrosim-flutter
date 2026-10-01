# F18-G3 Execution Ledger

Base: `f18-g2-shell-navigation@1a533a0a256fd1b79ab133baff7492f52fd4ddb7`

## Intent

Make the G2 session shell operational while reusing validated F17 TP and LAN
capabilities rather than rewriting them.

## TDD sequence

Initial RED:
- 0/4 G3 tests passed because G2 still used Manage/Supervision placeholders.

First implementation:
- introduced `F18TeacherSessionCoordinatorPage`;
- one shared `ElectroSimTpSessionController`;
- real F17 Manage Session dialog;
- real F17 Supervision panel;
- coordinator-owned LAN host;
- workspace Dashboard/Manage callback overrides.

First targeted run:
- 3/4 PASS;
- LAN scenario exposed a real 117 px horizontal overflow at 1100 px.

Correction:
- session top bar now uses dense navigation below 1200 px;
- no LAN protocol or TP engine change was required.

## Final code-head qualification

Run `36932771395` on
`13509e0e10f7f701337edf5e005b14df7cc60b8e`:

- analyze: PASS;
- G3 targeted tests: 4 PASS;
- application non-golden regressions: 87 PASS;
- historical goldens preserved: PASS;
- all package production scopes protected: PASS;
- `F18_G3_SESSION_DASHBOARD_GATE_PASS` emitted.

## Merge ruling

No automatic merge into `main`.

The next user-facing milestone after exact-head report qualification is the
first physical Mac validation candidate covering G1 + G2A + G2 + G3.
