# ElectroSim F18-G3 — Session & Dashboard Operational Plan

Base: `f18-g2-shell-navigation@1a533a0a256fd1b79ab133baff7492f52fd4ddb7`

1. Add RED tests for shared TP authority, real supervision, workspace handoff and LAN management.
2. Create an F18 teacher-session coordinator that owns TP controller + LAN host.
3. Replace G2 Manage/Supervision placeholders with qualified F17 functionality.
4. Add optional session Dashboard/Manage callbacks to F9 workspace while preserving historical standalone behavior.
5. Ensure session workspace uses coordinator callbacks and controller.
6. Verify compact/medium/expanded shell remains stable.
7. Run full application non-golden regression suite.
8. Preserve historical goldens.
9. Protect all non-app production packages.
10. Publish exact-head G3 report and marker.

No solver, topology, Canvas routing, TP engine or LAN protocol rewrite belongs to G3.
