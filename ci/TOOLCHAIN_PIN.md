# ElectroSim F0 toolchain pin — R5 Monterey compatibility

- Flutter: `3.38.10`
- Dart: `3.10.9`
- Channel: `stable`
- Framework revision: `c6f67dede3d4aa1aa7a69dd56a3494a5cde6cc80`

## Why this pin changed

R4 used Flutter 3.47.5 / Dart 3.13.4. On the target Mac running macOS Monterey 12,
Dart failed before any ElectroSim command could run because that Dart VM requires macOS 14.
R5 therefore pins Flutter 3.38.10, the latest version empirically reported to start on Monterey.
This is deliberately treated as a **candidate compatibility pin**: it becomes accepted for ElectroSim
only after the target Mac produces `F0_GATE_PASS`.

## Integrity

Archive SHA-256 values are stored in `TOOLCHAIN_LOCK.json` and checked before extraction for:
Linux x64, macOS Intel x64 and macOS Apple Silicon arm64. The bootstrap never edits shell profiles
or installs a system-wide Flutter SDK.

## Determinism rule

There is no automatic version fallback. If 3.38.10 fails on the actual Monterey machine, the failure
is recorded and a new candidate must explicitly pin another version before F1 can start.
