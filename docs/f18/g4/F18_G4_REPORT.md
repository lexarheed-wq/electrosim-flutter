# F18 — G4 Visual framework

Gate status: **PASS when the dedicated G4 workflow is green on this branch**.

## Scope

G4 qualifies the production visual contract only. It does not import any V1 runtime code or data.

The qualified visual descriptor is intentionally composed from the existing production contracts rather than introducing a redundant parallel registry:

- `F9PaletteDefinition`: electrical model, display identity, visual model, variant, terminals and supported modes.
- `F18ReferenceComponentMetrics`: board/palette/drag physical dimensions.
- `F18ComponentAssetVisual`: shared palette/drag/board renderer.
- `TerminalVisualProfile` and `CircuitVisualLayout`: physical terminal and rotation geometry.

## Acceptance

The gate requires:

- at least 20 critical electrical visual families;
- every production palette entry routed through the shared F18 renderer;
- no critical family falling back to the generic archetype painter;
- non-empty physical terminal contracts;
- stable board dimensions and rotation semantics;
- palette/canvas visual identity and variant persistence;
- vector production rendering; no photographic fallback;
- visual-state tests for appliances, machines, sources, PV, relay/contactor auxiliaries and semiconductor packages.

The current product catalog contains 69 palette references across CC, AC1, AC3 and PV. The dedicated gate tests the 20 critical families and then re-runs the complete visual regression set.

## Evidence contract

The branch workflow runs Flutter 3.38.10 / Dart 3.10.9 and executes:

- `f18_g4_visual_framework_gate_test.dart`
- `f18_point5_component_visual_identity_test.dart`
- `f18_g3r1_point08_visual_archetypes_test.dart`
- `f14_visual_identity_test.dart`
- `f20_catalog_visual_identity_test.dart`
- `f9_catalog_visual_uniqueness_test.dart`
- `c15_mode_wave2_test.dart`
- `f18_g3r1_point05_palette_contract_test.dart`

A green workflow is the evidence of qualification. No golden is updated automatically by this gate.

**Marker:** `F18_G4_VISUAL_FRAMEWORK_GATE_PASS`
