# ElectroSim 2 — RC1

Release candidate built from the F16-OFFICIAL baseline.

## Qualification

GitHub Actions run: 36589311448

All RC1 qualification jobs passed:

- transversal static analysis and automated tests;
- F16 catalog qualification;
- Linux qualification;
- Windows qualification;
- Android qualification;
- macOS qualification;
- iOS qualification;
- final release audit.

## Evidence

Artifacts produced by the qualification run:

- ELECTROSIM2_RC1_AUDIT
- RC1_F16_AUDIT_CATALOG
- rc1-evidence-linux
- rc1-evidence-windows
- rc1-evidence-android
- rc1-evidence-macos
- rc1-evidence-ios

## Visual regression policy

Historical pixel-golden suites are host-specific. RC1 does not regenerate them on Linux CI.
Portable behavior tests are executed across the current codebase and the previously approved
visual baseline is inherited. Any later UI change must trigger a controlled visual-baseline
review rather than silently rewriting golden references.

## Gate

```
ELECTROSIM2_RC1_GATE_PASS
```
