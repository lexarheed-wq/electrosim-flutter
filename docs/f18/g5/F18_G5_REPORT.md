# F18 — G5 Supported parity catalog

Gate status: **PASS when the dedicated G5 workflow is green on this branch**.

## Principle

G5 does not import the V1 palette, examples or fault library. The historical G0 matrix remains an immutable inventory snapshot. G5 qualifies only the families that the Flutter/Dart domain and runtime can simulate explicitly.

The production palette currently exposes **69 qualified references** across **15 categories**. A visible palette entry must have:

1. a canonical electrical model supported by the domain/runtime;
2. a mode restriction that never broadens the canonical model contract;
3. a separate visual identity when several physical products share one electrical model;
4. at least one supported electrical mode;
5. no dependency on legacy `exampleId`, script order, monkey-patch or V1 runtime data.

## Important architecture decision

`catalog_*` identifiers are visual identities only. They are forbidden as production electrical `modelType` values.

This is why, for example, a refrigerator can use the canonical `impedance` model while rendering through `catalog_appliance_2t`, and the CC and AC3 terminal blocks can share the canonical passive `terminal_block_5` model while keeping different terminal semantics, mode restrictions and visual variants.

The former temporary diode exception is removed: every visible component must now resolve through `CoreComponentModelContracts`.

## Mode integrity

The gate explicitly protects:

- CC-only distribution and semiconductor identities;
- AC1-only contactor/appliance identities;
- AC3-only motors, loads, contactors, protections and L1/L2/L3/N/PE distribution;
- PV-only array/controller/battery/inverter/load identities.

No triphasé distribution category may be exposed in CC.

## Evidence

The dedicated workflow runs:

- `f18_g5_supported_parity_gate_test.dart`;
- full catalog uniqueness and mode tests;
- catalog runtime tests;
- scenario catalog non-legacy checks;
- Flutter analysis.

A green workflow is the evidence of qualification.

**Marker:** `F18_G5_SUPPORTED_PARITY_GATE_PASS`
