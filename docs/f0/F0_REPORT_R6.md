# F0 R6 — Monterey guard correction candidate

## Trigger observed on the target Mac

The R5 screen recording proves that the compatibility toolchain now starts on the actual development host:

- host: macOS 12.7.6, Intel x86_64;
- Flutter archive integrity: PASS;
- Flutter 3.38.10 starts successfully;
- Dart 3.10.9 starts successfully.

The F0 gate then failed inside `f0_guard.py` with many findings such as:

`legacy-code-outside-reference:.toolchain/flutter/.../*.js`

Those files belong to the Flutter SDK downloaded under `.toolchain/`; they are not historical ElectroSim source and are not a migration of the legacy application. The R5 guard was therefore producing a false positive by recursively scanning the entire repository after the SDK bootstrap.

## R6 correction

`f0_guard.py` now scans only project-authored roots (`apps/`, `packages/`, `tools/`, `integration_test/`, `ci/`) and ignores generated/dependency directories. This preserves the actual F0 invariant: JavaScript/TypeScript implementation authored into the new ElectroSim source is rejected, while external SDK code is not classified as migrated legacy code.

Two regression tests were added:

1. a temporary `.toolchain/.../sdk_probe.js` must **not** fail the guard;
2. a temporary `apps/electrosim/lib/guard_regression_legacy.js` **must** fail the guard.

No F1 domain source has been introduced. No historical example or fault scenario has been migrated.

## Current decision

R6 is a **candidate**, not a validated F0 release. The target Mac must rerun:

```bash
./tools/bootstrap_flutter_and_run_f0.sh
```

The decisive success marker remains:

```text
F0_GATE_PASS
```

Only after that marker is observed may F1 start.

## Bootstrap cache reuse

R6 can reuse the verified Flutter 3.38.10 archive from a sibling R5 Monterey candidate. The archive is accepted only when its SHA-256 matches the locked value; otherwise the normal verified download path is used.
