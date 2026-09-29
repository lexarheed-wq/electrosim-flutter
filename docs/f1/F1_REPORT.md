# F1 R1 — Phase report

## Status

**CANDIDATE — target Dart gate required.**

F0 is physically validated on the target Monterey Mac (`F0_GATE_PASS`). F1 implementation is present, but this ChatGPT runtime does not contain a Dart/Flutter SDK, so F1 cannot be declared GO until `tools/bootstrap_flutter_and_run_f1.sh` produces `F1_GATE_PASS` on the target toolchain.

## Implemented

- Pure Dart `electrosim_domain` package.
- Typed IDs for circuit/component/source/terminal/connection.
- Electrical modes and explicit unit enum.
- Structured `DomainException` + error codes.
- Immutable `Terminal`, `ComponentInstance`, `SourceInstance`, `Connection`.
- Immutable/versioned `CircuitState`.
- Deterministic JSON round-trip contract.
- Duplicate-ID and missing-terminal-reference validation.
- Python + Dart architecture guards forbidding Flutter/UI dependencies in domain.
- Domain test suite covering serialization, equality, immutability and invalid inputs.
- Coverage gate at >= 90% line coverage for `lib/`.

## Checks executed in the authoring runtime

The following non-Dart checks are executed before packaging:

- F0 authored-code guard;
- frozen legacy ZIP verification;
- reference vector validation;
- F1 Python architecture guard;
- Python syntax checks;
- required F1 contract/static inventory.

The Dart-native checks remain target-gated because Dart is unavailable in this runtime.

## Target gate

Run:

```bash
chmod +x tools/*.sh
./tools/bootstrap_flutter_and_run_f1.sh
```

Required final marker:

```text
F1_GATE_PASS
```

Gate sequence includes the F0 UI regression, canonical `dart format` followed by a no-change format check, `dart analyze`, `dart test`, line coverage >= 90%, and the Dart architecture guard. The first target run may normalize whitespace in F1 Dart sources because the authoring runtime has no Dart formatter.

## GO/NO-GO

Current decision: **NO-GO for F2 until F1_GATE_PASS is observed.**
