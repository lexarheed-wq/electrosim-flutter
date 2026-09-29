# F17-R12 — Final native release qualification

Validated code head: `1043eb94bdcef9273a62af8bd97418fa1ed03833`

GitHub Actions run: `36647134499`

Gate marker:

```
F17_R12_FINAL_NATIVE_RELEASE_GATE_PASS
```

Toolchain:

- Flutter 3.38.10
- Dart 3.10.9 (project lock)
- dependency lock verified stable after `flutter pub get`

## Core regression

The final gate requires all of the following before native builds begin:

- full application dependency resolution;
- stable `apps/electrosim/pubspec.lock`;
- full Flutter static analysis;
- complete application test suite, including the reviewed F9 golden references;
- analysis and tests for critical F17 packages: storage, TP, AC solver, PV, energy and diagnostics.

All passed in run `36647134499`.

## Native release matrix

All five native targets passed release qualification and produced evidence artifacts:

| Target | Result | Evidence artifact | Artifact digest |
| --- | --- | --- | --- |
| Linux | PASS | `f17-r12-evidence-linux` | `sha256:2663686afd51d56a3df54d4fa3d26632427c23ec4149e902aa050fae86182d04` |
| Windows | PASS | `f17-r12-evidence-windows` | `sha256:0622c089b33c7cb901f6fe1efdb833fe7b4a042d0d93962409f90a2cace3e76b` |
| Android | PASS | `f17-r12-evidence-android` | `sha256:7b65c47e57531767b8552bb506768a6cfa53129aec09dfb858c190c6e8da5ea8` |
| macOS | PASS | `f17-r12-evidence-macos` | `sha256:acd36c25cd932d8aa1d2fe40d6c7a7ca79d721bc5c72122a44c8998181a8c946` |
| iOS | PASS | `f17-r12-evidence-ios` | `sha256:b349d2885769976409ee85503ee1b075d24a934c0cf5600e66bf931b11c292f2` |

Each target runs analysis, the application smoke test, LAN platform-configuration verification, a release build and SHA-256 artifact evidence.

## Generated LAN configuration

Because ElectroSim intentionally regenerates platform runners instead of versioning Android/iOS/macOS scaffolds, R12 applies and verifies LAN permissions after `flutter create`:

- Android: `android.permission.INTERNET` and cleartext WebSocket support for the classroom `ws://` transport;
- iOS: local-network usage description and local-network transport allowance;
- macOS: sandbox network client and network server entitlements for both Debug/Profile and Release runners;
- Linux/Windows: no additional generated permission manifest is required for the current direct-IP LAN transport.

## Corrections found by R12

The qualification gate detected and corrected:

- a stale F9 visual reference set; the replacement goldens were visually reviewed and bit-for-bit deterministic across two independent CI renders;
- an out-of-date application dependency lock after the persistence integration;
- the historical runner copy list using `electrosim_measurement` while the active package is `electrosim_measurements`;
- stdout contamination in the F17 runner-path protocol.

These issues were corrected before the final successful gate.

## Scope note

R12 is a native release qualification. Web is not included because the current classroom synchronization transport is implemented with native `dart:io` sockets.

A short physical Mac validation remains appropriate before distributing a user-facing candidate, specifically for real trackpad interaction, native rendering and LAN behavior on the target classroom hardware.
