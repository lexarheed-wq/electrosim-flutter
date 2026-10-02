# ElectroSim F18 — MagicPath parity execution plan

Status: **active**

Baseline: `f52da0acba9e93032433849756abfdea17dc442d`  
Branch: `f18-magicpath-parity`

## Authority

MagicPath project `456415562449448960` — **ElectroSim F18 — Professional Design System** is the mandatory product UI authority.

Qualified immutable references:

- Home Desktop — 1440×900 — `456415638643150848` / `456415638643150849`
- Workspace Desktop — 1440×900 — `456417407095963648` / `456417407095963649`
- Workspace Compact — 390×844 — `456417656019521536` / `456417656019521537`
- Troubleshooting Student — 820×1180 — `456418021750222848` / `456418021750222849`
- Foundations — `456416399569604608` / `456416399569604609`
- Core UI Library — `456416678377570304` / `456416678377570305`
- Electrical Visual Language V2 — `456416985736171520` / `456420930390990848`
- Wire Architecture G2A — `456432394111688704` / `456432394111688705`

## Definition of done

A screen is not complete because its functional tests pass. It is complete only when:

1. navigation and product behavior match the approved flow;
2. the Flutter geometry, hierarchy, spacing, typography, colors and responsive behavior match the qualified MagicPath reference;
3. electrical device identity matches Electrical Visual Language V2;
4. palette and Canvas use the same device identity;
5. routed conductors match G2A rules: orthogonal, balanced, components on straight segments, no automatic different-net crossing, no device on a bend;
6. the entire committed scene is visible after initial load, with no clipping under the palette or inspector;
7. Flutter goldens exist at each qualified reference resolution and are accepted only after human comparison with the MagicPath source;
8. all existing non-golden regressions remain green;
9. final Mac physical validation confirms the real trackpad, routing and visual behavior.

## Stage 1 — Proven video discrepancies

- Replace the legacy raw model label rendered over the component body.
- Use the F18 renderer directly in `SimulatorCanvas` instead of superimposing F18 glyphs over the legacy generic card.
- Differentiate the eight qualified electrical archetype housings.
- Fit the complete routed scene, including wire bends, inside the visible Canvas on initial load and recenter.
- Preserve G2A routing and G3R1 functionality.
- Add exact MagicPath reference identities to the production parity contract.

## Stage 2 — Workspace exact reconstruction

- Reconstruct Workspace Desktop at 1440×900.
- Reconstruct Workspace Compact at 390×844.
- Match top bar, palette, Canvas, inspector, status bar, spacing and panel behavior.
- Add approved F18 Workspace goldens after direct visual comparison.

## Stage 3 — Home and Troubleshooting exact reconstruction

- Home Desktop 1440×900.
- Troubleshooting Student 820×1180.
- Add approved goldens after direct visual comparison.

## Stage 4 — Core UI and responsive closure

- Verify the 24 Core UI components in production routes.
- Verify compact/medium/expanded behavior and zero overflow.
- Verify focus, touch targets and accessibility.

## Stage 5 — Physical qualification

- Build universal macOS candidate.
- Repeat the user video flow.
- Compare side-by-side with MagicPath references.
- Close only when no unexplained visible deviation remains.


## CI authority on convergence branch

For `f18-magicpath-parity`, the blocking qualification authority is
`F18 MagicPath Parity` plus the current platform qualification. Historical
F0/F1/F8/F9 freeze gates remain preserved for their historical branches but
are intentionally skipped on this convergence branch because they compare
against pre-F18 frozen baselines and otherwise report expected F18 UI changes
as regressions.

Stage 2 no-clipping contract uses a 24 px minimum visible safety inset while
the exact visual placement is verified by the qualified MagicPath reference
captures rather than by an obsolete 46 px G3R1 margin.
