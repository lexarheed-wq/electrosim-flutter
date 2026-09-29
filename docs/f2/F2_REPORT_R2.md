# F2 R2 — Gate harness correction for Monterey

## Trigger

The first physical execution of F2 R1 on the validated macOS Monterey host ended inside `flutter_tools` while writing to stdout. The visible stack trace terminates in `Stdio.stdoutWrite` / `StdoutLogger`, before any F2 package result was produced.

## Root cause

The gate scripts extracted the Flutter version with:

```bash
flutter --version | head -1 | awk '{print $2}'
```

With `set -o pipefail`, `head` may close stdout after the first line while Flutter is still emitting output. Flutter 3.38.10 can then receive `EPIPE` (`Broken pipe`) and print the internal stack trace observed on the target Mac.

This is a gate-harness defect, not a `TopologyEngine` failure.

## Correction

F0, F1 and F2 gate scripts now capture the complete command output first, then parse the first line from the already-captured string:

```bash
FLUTTER_VERSION_OUTPUT="$(flutter --version)"
ACTUAL_FLUTTER="$(awk 'NR==1 {print $2}' <<< "$FLUTTER_VERSION_OUTPUT")"
```

No consumer terminates the Flutter stdout stream prematurely.

## Regression protection

`f2_static_contract_check.py` now rejects any gate script containing the unsafe `flutter --version | head` / `head -1` pattern and requires the safe full-output capture in all three cumulative gates.

## Status

F2 remains **CANDIDATE** until the corrected target run reaches `F2_GATE_PASS`.
