# ElectroSim F18-G1B — Design System qualification report

## Status

Qualified visual source: **MagicPath**  
Project: `ElectroSim F18 — Professional Design System`  
Project ID: `456415562449448960`

Qualification marker: `F18_G1_DESIGN_SYSTEM_GATE_PASS`

The original Figma file `TyYIfxMB0jPVIEcJPGsOwI` is retained only for optional later comparison; the Starter MCP quota is not a blocking dependency for G1B.

## Approved visual evidence

The four required reference screens were reviewed together and approved by the user on 2026-10-01:

- Home Desktop — 1440×900 — component `456415638643150848` / revision `456415638643150849`
- Workspace Desktop — 1440×900 — component `456417407095963648` / revision `456417407095963649`
- Workspace Compact — 390×844 — component `456417656019521536` / revision `456417656019521537`
- Troubleshooting Student — 820×1180 — component `456418021750222848` / revision `456418021750222849`

Supporting design assets:
- Foundations — component `456416399569604608` / revision `456416399569604609`
- 24-component Core UI Library — component `456416678377570304` / revision `456416678377570305`
- Electrical Visual Language V2 — component `456416985736171520` / revision `456420930390990848`

Electrical Visual Language V2 contains 8 qualified archetypes: source, protection, control, load, rotating machine, measurement, conversion, PV/energy.

## Flutter synchronization

Production changes are restricted to `packages/electrosim_ui_kit/lib/**`.

Qualified additions:
- `typography_tokens.dart`
- `component_tokens.dart`
- `electrical_visual_tokens.dart`
- synchronized `design_tokens.dart`
- synchronized `electrosim_theme.dart`
- public exports in `electrosim_ui_kit.dart`

Preserved breakpoint contract:
- compact < 600
- medium 600–1000
- expanded > 1000

Accessibility/interaction constraints:
- primary touch target ≥ 48 px
- electrical terminal hit target = 48 px
- electrical terminal visual diameter = 16 px
- UI selection never implies electrical state
- phase/polarity never relies on color alone

## Automated qualification evidence

Dedicated CI run: `36882699136`  
Qualified code head before this report-only commit: `486ff6cd6c95f8b53239a0006fdbf75b1e722974`

Results:
- Flutter 3.38.10 / Dart 3.10.9: PASS
- Python mapping contract tests: 4/4 PASS
- token mapping CLI: `F18_G1_TOKEN_MAPPING_PASS`
- protected-source drift guard: PASS
- UI kit analyze: PASS
- UI kit tests: **12 PASS**
- application analyze: PASS
- application functional tests: **72 PASS**
- historical F9 golden preservation: `F18_G1_LEGACY_GOLDENS_PRESERVED`
- visual approval evidence: `F18_G1_VISUAL_EVIDENCE_PASS`
- gate marker: `F18_G1_DESIGN_SYSTEM_GATE_PASS`

## Historical F9 goldens

The first full application test attempt demonstrated expected visual drift in the historical F9 goldens after approved F18 token synchronization. Those F9 goldens were **not regenerated and not auto-accepted**.

G1B therefore:
1. preserves the F9 golden files and their test unchanged;
2. runs all non-golden application tests;
3. fails if any historical F9 golden evidence is modified;
4. defers new F18 Flutter goldens until approved F18 screens are actually implemented in later UI gates.

## Scope integrity

No G1B production modification is authorized under:
- `apps/electrosim/lib/**`
- domain/topology/solver packages
- PV/energy/measurement/diagnostics packages
- TP/storage packages

G1B establishes the qualified design system and Flutter token contracts only. Runtime screen reconstruction starts in the subsequent F18 UI gates.

## Outcome

G1B is qualified for handoff to the next F18 implementation gate once the report-only exact-head CI run is green.

`F18_G1_DESIGN_SYSTEM_GATE_PASS`
