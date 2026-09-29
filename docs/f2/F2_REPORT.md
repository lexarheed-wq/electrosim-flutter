# F2 R1 — Phase report

## Status

**CANDIDATE — target Dart gate required.**

F1 is physically validated on the Monterey target (`F1_GATE_PASS`), with 19 domain tests passing, 97.67% line coverage (377/386) and the Dart architecture guard passing with zero errors. Evidence is archived under `reference/f1/`.

F2 implementation is authored as a pure Dart `electrosim_topology` package. This ChatGPT runtime does not contain the locked Dart/Flutter SDK, so F2 cannot be declared GO until the F2 gate executes on the validated target toolchain.

## Implemented

- deterministic union-find compilation of enabled conductors;
- canonical topology nodes independent of connection input order;
- terminal → node mapping;
- component/source incident-node maps;
- explicit disabled-connection handling;
- conservative floating-node detection;
- isolated component/source findings;
- incompatible phase/polarity merge detection;
- immutable `TopologyGraph` output;
- property-style connectivity tests;
- no `CircuitState` mutation test;
- Python and Dart architecture guards.

## F2 quality gate

Required by the director specification:

- topology corpus 100% green;
- connectivity property tests green;
- no mutation of `CircuitState`;
- audit archived.

The candidate also uses a >= 90% topology package line-coverage threshold.

## One-command validation

From F2 onward the user-facing entry point is simply:

```bash
./validate.sh
```

It searches for the already-extracted Flutter 3.38.10 SDK in sibling ElectroSim candidates before falling back to the locked bootstrap. There is no repeated manual SDK setup.

Expected final marker:

```text
F2_GATE_PASS
```

## GO/NO-GO

Current decision: **NO-GO for F3 until F2_GATE_PASS is observed.**
