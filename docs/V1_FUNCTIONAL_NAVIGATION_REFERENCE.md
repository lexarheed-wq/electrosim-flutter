# ElectroSim V1 — Functional/navigation reference

## Purpose

This document turns the supplied V1 screen recording into a reproducible acceptance reference for the Flutter rebuild.

This contract is intentionally about **functions, workflow and navigation**. The current Flutter visual theme may be retained. V1 colors, decoration, background art and typography are not blocking acceptance criteria here.

## Canonical source

- Recording: `Enregistrement de l’écran 2026-10-03 à 18.59.51.mov`
- SHA-256: `5727d0e521d04590c3c3ffdca3c054f64e481d3aac6617858bb527681abde704`
- Duration: 118.05 s
- Native frame: 2880 × 1800

`reference/v1/v1_functional_navigation_contract.json` is the machine-readable authority. `reference/v1/tools/extract_v1_reference_frames.py` reproduces the exact canonical stills from the recording and rejects a different source video.

## Canonical navigation states

1. `HOME` (0 s): global entry point with Create session, Maintenance center and Design center.
2. `CREATE_SESSION_DIALOG` (8 s): configuration before entering the teacher pedagogical session.
3. `WAITING_ROOM` (16 s): join information/QR or code, connected-student state and progression into the class/session.
4. `TEACHER_DASHBOARD` (24 s): session hub. It exposes Home, Dashboard, Manage session, Cabling, Fault diagnosis and Supervision without routing unrelated actions directly into the simulator.
5. `CABLING_ACTIVITY_SETUP` (32 s): activity preparation/configuration is a distinct step before the workshop.
6. `SUPERVISION` (40 s): student/activity monitoring remains a distinct teacher screen and returns to the dashboard.
7. `MAINTENANCE_CENTER` (48 s): separate hub for fault library, fault search and student-situation validation.
8. `STUDENT_SITUATION_VALIDATION` (52 s): select a reference circuit and fault/scenario before launch/validation, with an explicit return to Maintenance center.
9. `DESIGN_CENTER` (64 s): separate hub for scheme library and preparation of a design/cabling activity.
10. `WORKSHOP` (84 s): circuit construction/simulation workspace with component palette, canvas, workspace tools/properties, Save to library and Quit workshop.

## Observed route graph

```text
HOME
├─ create_session → CREATE_SESSION_DIALOG
│  └─ create_session → WAITING_ROOM
│     └─ advance_session_flow → TEACHER_DASHBOARD
│        ├─ open_cabling → CABLING_ACTIVITY_SETUP → TEACHER_DASHBOARD
│        └─ open_supervision → SUPERVISION → TEACHER_DASHBOARD
├─ open_maintenance_center → MAINTENANCE_CENTER
│  └─ student_situation_validation → STUDENT_SITUATION_VALIDATION → MAINTENANCE_CENTER
└─ open_design_center → DESIGN_CENTER
   └─ prepare_activity_or_open_scheme → WORKSHOP
      └─ quit_workshop → DESIGN_CENTER → HOME
```

## Visible controls not exercised in the recording

The recording visibly exposes these entry points but does not prove their complete destination workflow:

- Dashboard → Manage session
- Dashboard → Fault diagnosis
- Maintenance center → Fault library
- Maintenance center → Fault search
- Design center → Scheme library

They remain required controls. The contract deliberately does **not** invent destination behavior that was not exercised in the recording.

## Non-regression rules

- A canonical screen must be reachable by its semantic parent flow.
- Return/back/quit actions must return to the parent represented by V1.
- Teacher Dashboard actions remain separate workflows; they must not all redirect into the simulator.
- Activity configuration remains a distinct step where V1 shows one.
- Maintenance and Design remain separate centers.
- The Workshop remains an activity/design child screen and exposes an explicit exit path.
- Current Flutter styling can remain; navigation equivalence is the blocking criterion for this phase.

## CI isolation

The V1 reference utilities live under `reference/v1/tools/`, not the repository-wide `tools/` directory. This prevents a documentation/reference-only change from incorrectly triggering legacy F0–F3 architecture gates. Those legacy gates currently report pre-existing `packages/electrosim_scenarios` findings unrelated to this point.

## Point-2 acceptance gate

Point 2 passes only when:

1. the source recording fingerprint is fixed;
2. every canonical state has an exact timestamp and frame SHA-256;
3. canonical frames can be reproduced byte-for-byte from the source recording;
4. every transition references valid states;
5. the required top-level V1 actions are present in the contract;
6. no application/runtime/solver source file is changed by establishing the reference;
7. the existing M13-R2 core guard remains green.

This reference becomes the authority for subsequent Chromium navigation proofs.
