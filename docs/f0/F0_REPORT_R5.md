# F0 R5 — Monterey compatibility candidate

## Trigger

The R4 bootstrap downloaded and verified Flutter 3.47.5 successfully on the target Mac, but Dart then stopped with:

`VM initialization failed: Current Mac OS X version 12.0 is lower than minimum supported version 14.0`

The failure occurs before ElectroSim analysis/tests; it is therefore a host/toolchain compatibility failure, not an ElectroSim code failure.

## Change

The F0 toolchain is explicitly repinned to Flutter 3.38.10 / Dart 3.10.9, framework revision
`c6f67dede3d4aa1aa7a69dd56a3494a5cde6cc80`. Archive SHA-256 values are locked for Linux x64,
macOS Intel and macOS Apple Silicon. CI uses the same Flutter version.

No F1 domain code has been introduced. No historical example or fault scenario has been migrated.

## Validation status

Static F0 checks can be rerun in the build environment. The decisive checks remain:

- `flutter analyze` on the target Monterey Mac;
- `flutter test` on the target Monterey Mac;
- final marker `F0_GATE_PASS`.

Until those succeed, the phase decision remains **NO-GO** and F1 remains blocked.

## Fallback policy

No automatic downgrade is allowed. If Flutter 3.38.10 fails to start on the actual Monterey host,
the exact error becomes the input to a new, explicitly versioned compatibility candidate.
