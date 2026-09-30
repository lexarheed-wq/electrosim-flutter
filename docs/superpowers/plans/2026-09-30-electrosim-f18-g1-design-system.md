# ElectroSim F18-G1 Design System Figma → Flutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Établir Figma comme source de vérité visuelle d’ElectroSim, construire le Design System G1, synchroniser ses tokens vers `electrosim_ui_kit` et qualifier le tout sans modifier le moteur/runtime F17.

**Architecture:** G1 suit un flux Design-System-First : écrire dans Figma les fondations, composants fondamentaux, langage visuel électrique et quatre écrans de référence ; figer ensuite leurs identifiants/variables dans des artefacts machine-lisibles Git ; enfin synchroniser les tokens vers Flutter et protéger la correspondance avec tests et CI. Les écrans métier Flutter ne sont pas reconstruits en G1 : G2/G3 les consommeront.

**Tech Stack:** Figma MCP Plugin API, Flutter 3.38.10, Dart 3.10.9, Python 3 stdlib, GitHub Actions, `electrosim_ui_kit`.

**Spec:** `docs/superpowers/specs/2026-09-30-electrosim-f18-g1-design-system-design.md`

## Global Constraints

- Base d’exécution : `main@591b8d6386de36093ed22deaab785c38245f5331`.
- Toolchain : Flutter 3.38.10 / Dart 3.10.9.
- Figma est la source de vérité visuelle ; le code ne peut pas devenir une source de substitution si l’écriture Figma échoue.
- Le fichier Figma G1 porte le nom exact `ElectroSim F18 — Design System G1`.
- Pages Figma exactes : `00 Foundations`, `01 Components`, `02 Electrical Visual Language`, `03 Reference Screens`.
- Frames de référence obligatoires : Accueil 1440×900, Workspace 1440×900, Workspace compact 390×844, Recherche de dérangement élève.
- Les breakpoints restent : compact < 600, medium 600–1000, expanded > 1000.
- Aucun fichier sous `apps/electrosim/lib/**`, `packages/electrosim_domain/**`, `packages/electrosim_topology/**`, `packages/electrosim_solver_dc/**`, `packages/electrosim_solver_ac/**`, `packages/electrosim_pv/**`, `packages/electrosim_energy/**`, `packages/electrosim_measurements/**`, `packages/electrosim_diagnostics/**`, `packages/electrosim_tp/**` ou `packages/electrosim_storage/**` ne peut être modifié par G1.
- Les seuls fichiers de production Flutter modifiables sont sous `packages/electrosim_ui_kit/lib/**`.
- Aucune nouvelle dépendance de police ou design package n’est ajoutée en G1 ; la famille typographique Flutter reste plateforme-native et cette exception est enregistrée dans le mapping.
- Touch target principal ≥ 48 px.
- Contraste texte normal : WCAG AA ≥ 4.5:1 ; grand texte/UI pertinent ≥ 3:1.
- Aucun état électrique n’est inféré depuis un état UI.
- Aucun golden n’est auto-accepté par CI.
- Une seule validation humaine visuelle est autorisée dans le flux normal : revue groupée des quatre écrans Figma avant verrouillage de la source de vérité.
- Si Figma refuse l’écriture à cause du siège `View`, arrêter uniquement le sous-gate Figma et demander l’action minimale nécessaire ; ne pas continuer avec une source visuelle de remplacement.

## Review Focus

1. **Permission Figma en lecture seule** — le workflow doit s’arrêter proprement avant toute pseudo-synchronisation Flutter ; Task 1 exerce ce cas.
2. **Valeur Figma manquante ou dupliquée** — le mapping doit échouer plutôt que choisir silencieusement une valeur ; Task 6 l’exerce.
3. **Contraste insuffisant après ajustement visuel** — le gate doit détecter le couple fautif avec ratio calculé ; Task 6 l’exerce.
4. **Dérive Flutter hors UI kit** — une modification runtime/moteur doit faire échouer G1 même si tous les tests UI passent ; Task 8 l’exerce.
5. **Reference Screen joli mais structurellement faux** — les quatre frames doivent être composées de variables/composants éditables, sans capture raster complète ni texte tronqué ; Tasks 3–5 l’exercent.

---

## File Structure

### Create

- `docs/f18/g1/F18_G1_FIGMA_REFERENCE.json` — fileKey, URL, pages, frames et IDs stables.
- `docs/f18/g1/F18_G1_TOKEN_MAPPING.json` — mapping machine-lisible Figma → Dart.
- `docs/f18/g1/F18_G1_VISUAL_APPROVAL.md` — preuve de revue groupée des quatre frames.
- `docs/f18/g1/F18_G1_REPORT.md` — rapport final.
- `docs/f18/g1/F18_G1_EXECUTION_LEDGER.md` — rulings, IDs Figma et preuves.
- `docs/f18/g1/reference_screens/home-desktop.png`
- `docs/f18/g1/reference_screens/workspace-desktop.png`
- `docs/f18/g1/reference_screens/workspace-compact.png`
- `docs/f18/g1/reference_screens/troubleshooting-student.png`
- `tools/f18_g1_design_system.py` — validation mapping, contraste, drift, génération/check tokens.
- `tools/test_f18_g1_design_system.py` — tests Python du gate.
- `packages/electrosim_ui_kit/lib/src/typography_tokens.dart`
- `packages/electrosim_ui_kit/lib/src/component_tokens.dart`
- `packages/electrosim_ui_kit/lib/src/electrical_visual_tokens.dart`
- `packages/electrosim_ui_kit/test/f18_g1_token_contract_test.dart`
- `.github/workflows/f18-g1-design-system.yml`

### Modify

- `packages/electrosim_ui_kit/lib/src/design_tokens.dart`
- `packages/electrosim_ui_kit/lib/src/electrosim_theme.dart`
- `packages/electrosim_ui_kit/lib/electrosim_ui_kit.dart`
- `packages/electrosim_ui_kit/test/design_system_test.dart`

### Read only

- `docs/f18/g0/F18_G0_REPORT.md`
- `docs/f18/g0/F18_PRODUCT_PARITY.csv`
- `docs/f18/g0/F18_CAPABILITY_PARITY.csv`
- `docs/f9/F9_COMPONENT_VISUAL_LANGUAGE.md`
- `docs/f9/F9_COMPONENT_RENDER_CONTRACT.md`
- `docs/f9/F9_ACCESSIBILITY_AND_INPUT_SPEC.md`
- `apps/electrosim/lib/main.dart`
- `apps/electrosim/lib/f9_component_visuals.dart`

---

### Task 1: Establish the writable Figma source of truth

**Files:**
- Create: `docs/f18/g1/F18_G1_FIGMA_REFERENCE.json`
- Create: `docs/f18/g1/F18_G1_EXECUTION_LEDGER.md`

**Interfaces:**
- Consumes: Figma plan key `team::1683861915998326637`.
- Produces: `fileKey`, `fileUrl`, and page IDs for exactly four pages.
- Produces JSON keys:
  - `schemaVersion: 1`
  - `fileName`
  - `fileKey`
  - `url`
  - `planKey`
  - `pages.foundations|components|electricalVisualLanguage|referenceScreens.nodeId`
  - `referenceFrames` initially empty.

- [ ] **Step 1: Load required Figma skills**
  Load `figma-create-new-file`, `figma-use`, `figma-generate-library`, then re-check `whoami`.

- [ ] **Step 2: Perform the write-capability probe**
  Call Figma `create_new_file` with:
  - fileName: `ElectroSim F18 — Design System G1`
  - planKey: `team::1683861915998326637`
  - editorType: `design`

  Expected:
  - success → capture returned `file_key`/URL and continue;
  - permission failure → record exact error in ledger, stop G1 execution, request only the minimum Figma permission change, and do not create Flutter tokens.

- [ ] **Step 3: Inspect the new file before mutation**
  Read pages, local variables, styles and libraries. Expected: blank/new-file state or known starter content only.

- [ ] **Step 4: Create the exact four-page skeleton**
  Use sequential `use_figma` mutations with deterministic page names:
  `00 Foundations`, `01 Components`, `02 Electrical Visual Language`, `03 Reference Screens`.
  Delete no unknown content; reuse the initial blank page by renaming it where safe.

- [ ] **Step 5: Verify page structure**
  Read back page IDs/names. Expected: each required page appears exactly once.

- [ ] **Step 6: Commit Figma reference + ledger**
  Commit message: `F18-G1: register writable Figma design source`.

### Task 2: Build and validate Figma foundations

**Files:**
- Modify: `docs/f18/g1/F18_G1_FIGMA_REFERENCE.json`
- Modify: `docs/f18/g1/F18_G1_EXECUTION_LEDGER.md`

**Interfaces:**
- Consumes: Task 1 `fileKey` and Foundations page ID.
- Produces Figma variable/style sets for UI colors, electrical colors, spacing, radii, geometry, motion and typography.
- Produces stable Figma variable IDs later consumed by Task 6.

- [ ] **Step 1: Lock foundation inventory before mutation**
  Required UI tokens:
  `ui/primary`, `ui/on-primary`, `ui/secondary`, `ui/background`, `ui/surface`, `ui/surface-raised`, `ui/surface-muted`, `ui/outline`, `ui/text-primary`, `ui/text-secondary`, `ui/text-disabled`, `ui/success`, `ui/warning`, `ui/danger`, `ui/info`, `ui/focus`.

  Required electrical tokens:
  `electrical/dc-positive`, `electrical/dc-negative`, `electrical/l1`, `electrical/l2`, `electrical/l3`, `electrical/neutral`, `electrical/protective-earth`.

  Required spacing: 4, 8, 12, 16, 24, 32.
  Required radius roles: compact, card, panel, dialog.
  Required geometry roles: minimum-touch-target, palette-width, inspector-width, medium-panel-width, status-bar-height, terminal-hit-target.
  Required motion roles: instant-feedback, short-transition, panel-transition.

- [ ] **Step 2: Seed values from current Flutter tokens**
  Import current values from `design_tokens.dart` as initial values. New roles without current equivalents are chosen once in Figma according to the approved direction and recorded in the ledger. Do not alter electrical colors merely for aesthetic uniformity.

- [ ] **Step 3: Create variables with explicit scopes and aliases**
  Primitive values stay hidden from normal property pickers; semantic tokens alias primitives. No variable uses `ALL_SCOPES`.

- [ ] **Step 4: Create text styles**
  Required roles: Display; Heading L/M/S; Title L/M/S; Body L/M/S; Label L/M/S; Technical value; Technical unit; Diagnostic mono if used.
  Use a Figma-available sans-serif authoring font. Record the explicit Flutter exception: runtime uses platform-native family while numerical size/weight/line-height remain mapped.

- [ ] **Step 5: Build Foundations specimen**
  Build a single editable specimen frame showing semantic colors, typography, spacing, radii, controls geometry and electrical colors. No full-screen raster.

- [ ] **Step 6: Structural and visual validation**
  Verify variable names/scopes, duplicate count = 0, text style names, and specimen clipping. Take one Foundations screenshot; apply one targeted fix pass only if needed.

- [ ] **Step 7: Record variable/style IDs**
  Update Figma reference/ledger with collection IDs, token IDs and style IDs.

- [ ] **Step 8: Commit reference updates**
  Commit message: `F18-G1: record qualified Figma foundations`.

### Task 3: Build fundamental Figma UI components

**Files:**
- Modify: `docs/f18/g1/F18_G1_FIGMA_REFERENCE.json`
- Modify: `docs/f18/g1/F18_G1_EXECUTION_LEDGER.md`

**Interfaces:**
- Consumes: Task 2 variables/styles.
- Produces component/component-set IDs for:
  Button Primary, Button Secondary, Button Tertiary, Icon Button, Search Field, Text Field, Select, Toggle, Checkbox, Radio, Chip/Status, Card, Navigation Item, Toolbar Action, Segmented Control, Tabs, Palette Item, Property Row, Inspector Section, Status Bar Item, Empty State, Inline Error, Snackbar, Dialog.
- State enum where applicable: `default|hover|pressed|focused|selected|disabled|loading|error`.
- Size enum where applicable: `compact|regular`.

- [ ] **Step 1: Discover reusable local/library assets**
  Call Figma library discovery before search. Reuse only assets whose API, variable binding and editability satisfy G1.

- [ ] **Step 2: Create components in dependency order**
  Build low-level controls first, then cards/navigation/palette/inspector/dialog. Bind fills, strokes, spacing and radii to Task 2 variables.

- [ ] **Step 3: Prevent variant explosion**
  If a component’s Size × Style × State matrix exceeds 30 variants, split it into a smaller component set plus properties/sub-components; icons use INSTANCE_SWAP rather than icon variants.

- [ ] **Step 4: Create one Components review frame**
  Show representative states as instances; keep main components outside the review frame.

- [ ] **Step 5: Validate structure**
  Verify each required component exists exactly once, representative instances link to main components, no placeholder text remains, and all required states are present where applicable.

- [ ] **Step 6: Validate appearance**
  Take one screenshot of the review frame; fix clipping/contrast/layout defects only, then one post-fix screenshot if necessary.

- [ ] **Step 7: Record component IDs**
  Persist component/component-set IDs in Figma reference/ledger.

- [ ] **Step 8: Commit reference updates**
  Commit message: `F18-G1: record Figma component library identities`.

### Task 4: Build the electrical visual language and four reference screens

**Files:**
- Modify: `docs/f18/g1/F18_G1_FIGMA_REFERENCE.json`
- Modify: `docs/f18/g1/F18_G1_EXECUTION_LEDGER.md`

**Interfaces:**
- Consumes: Tasks 2–3 foundations/components.
- Produces archetype cards for `source`, `protection`, `control`, `load`, `rotating-machine`, `measurement`, `conversion`, `pv-energy`.
- Produces exact frames:
  - `Reference/Home/Desktop` 1440×900
  - `Reference/Workspace/Desktop` 1440×900
  - `Reference/Workspace/Compact` 390×844
  - `Reference/Troubleshooting/Student` 820×1180

- [ ] **Step 1: Build Electrical Visual Language archetypes**
  Each archetype documents silhouette, terminal placement, markings, palette simplification, canvas rendering, UI states and electrical states. Explicitly separate `selected/focused/dragging` from `energized/running/faulted`.

- [ ] **Step 2: Build Home desktop reference**
  Must expose exactly three primary entry cards plus secondary `Rejoindre une session`, with professional density and no redundant entry choice.

- [ ] **Step 3: Build Workspace desktop reference**
  Must simultaneously show top bar, palette, dominant canvas, inspector, status bar, selection state and a small demonstrator circuit. Demonstrator components are visual examples, not new runtime support.

- [ ] **Step 4: Build Workspace compact reference**
  Canvas remains dominant; palette and inspector are invoked contextually without permanent side panels; no clipping at 390×844.

- [ ] **Step 5: Build Troubleshooting student reference**
  Must show Canvas, deployable diagnostic sheet, measurement progress and repair gating; no student EIE coach.

- [ ] **Step 6: Structural audit**
  For each reference frame: verify dimensions, descendant type counts, component instances, variable bindings, no full-screen raster/image capture, no placeholder nodes and no clipped text.

- [ ] **Step 7: Visual audit**
  Take one screenshot per reference frame at readable size. Apply targeted fixes only to defects found.

- [ ] **Step 8: Record frame IDs**
  Populate `referenceFrames.homeDesktop|workspaceDesktop|workspaceCompact|troubleshootingStudent` with node ID and dimensions.

- [ ] **Step 9: Commit reference updates**
  Commit message: `F18-G1: record electrical language and reference frames`.

### Task 5: Obtain the single human visual approval and freeze reference images

**Files:**
- Create: `docs/f18/g1/F18_G1_VISUAL_APPROVAL.md`
- Create: four PNGs under `docs/f18/g1/reference_screens/`
- Modify: `docs/f18/g1/F18_G1_EXECUTION_LEDGER.md`

**Interfaces:**
- Consumes: Task 4 four frame IDs.
- Produces approval marker `F18_G1_FIGMA_VISUAL_APPROVED`.
- Produces PNG references whose filenames are fixed by File Structure above.

- [ ] **Step 1: Export all four final screenshots**
  Export from exact Figma frame IDs; do not crop or retouch outside Figma.

- [ ] **Step 2: Present the four screens together**
  Ask one combined visual question: whether these four frames establish the desired professional direction. Do not ask separate approvals per screen.

- [ ] **Step 3: If rejected, apply only requested corrections**
  Update affected frames, re-run structural/visual audit for those frames, and re-present the grouped set once.

- [ ] **Step 4: On approval, freeze evidence**
  Write `F18_G1_VISUAL_APPROVAL.md` with marker, fileKey, frame IDs, dimensions and approved image filenames.

- [ ] **Step 5: Commit**
  Commit message: `F18-G1: freeze approved Figma reference screens`.

### Task 6: Create machine-readable token mapping and validation tooling

**Files:**
- Create: `docs/f18/g1/F18_G1_TOKEN_MAPPING.json`
- Create: `tools/f18_g1_design_system.py`
- Create: `tools/test_f18_g1_design_system.py`

**Interfaces:**
- `load_mapping(root: pathlib.Path) -> dict[str, object]`
- `validate_mapping(mapping: dict[str, object]) -> list[str]`
- `contrast_ratio(foreground_hex: str, background_hex: str) -> float`
- `find_forbidden_g1_changes(paths: list[str]) -> list[str]`
- CLI: `python3 tools/f18_g1_design_system.py --check [--base-sha <sha>]`
- Mapping token item fields:
  `figmaName,figmaVariableId,kind,value,dartOwner,dartField`.
- Mapping exceptions fields:
  `id,reason,scope`.

- [ ] **Step 1: Write failing Python tests**
  Tests:
  - required token inventory is complete;
  - duplicate `figmaName` rejected;
  - duplicate `dartOwner.dartField` rejected;
  - missing/blank Figma variable ID rejected;
  - `ui/text-primary` on `ui/surface` ≥ 4.5;
  - `ui/on-primary` on `ui/primary` ≥ 4.5;
  - `ui/text-secondary` on `ui/surface` ≥ 4.5;
  - platform-font-family exception exists and is non-empty;
  - G1 drift guard rejects `apps/electrosim/lib/main.dart` and protected packages.

- [ ] **Step 2: Verify RED**
  Run: `python3 -m unittest tools.test_f18_g1_design_system -v`.
  Expected: FAIL because validator/mapping do not yet exist.

- [ ] **Step 3: Build mapping from qualified Figma data**
  Use Task 2 IDs/values; do not type invented node IDs. Every production token consumed in G1 must map to a Figma variable or documented exception.

- [ ] **Step 4: Implement minimal validator**
  No third-party Python dependencies. Contrast calculation follows WCAG relative luminance.

- [ ] **Step 5: Verify GREEN**
  Same unittest command. Expected: all tests PASS.

- [ ] **Step 6: Verify CLI**
  Run: `python3 tools/f18_g1_design_system.py --check`.
  Expected: `F18_G1_TOKEN_MAPPING_PASS`.

- [ ] **Step 7: Commit**
  Commit message: `F18-G1: validate Figma to Flutter token mapping`.

### Task 7: Synchronize qualified tokens into electrosim_ui_kit

**Files:**
- Modify: `packages/electrosim_ui_kit/lib/src/design_tokens.dart`
- Create: `packages/electrosim_ui_kit/lib/src/typography_tokens.dart`
- Create: `packages/electrosim_ui_kit/lib/src/component_tokens.dart`
- Create: `packages/electrosim_ui_kit/lib/src/electrical_visual_tokens.dart`
- Modify: `packages/electrosim_ui_kit/lib/src/electrosim_theme.dart`
- Modify: `packages/electrosim_ui_kit/lib/electrosim_ui_kit.dart`
- Modify: `packages/electrosim_ui_kit/test/design_system_test.dart`
- Create: `packages/electrosim_ui_kit/test/f18_g1_token_contract_test.dart`

**Interfaces:**
- Preserve public classes: `ElectroSimColors`, `ElectroSimSpacing`, `ElectroSimRadii`, `ElectroSimMotion`, `ElectroSimGeometry`.
- Add: `abstract final class ElectroSimTypographyTokens`.
- Add: `abstract final class ElectroSimComponentTokens`.
- Add: `abstract final class ElectroSimElectricalVisualTokens`.
- Add: `abstract final class ElectroSimTypography { static TextTheme apply(TextTheme base); }`.
- `ElectroSimTheme.light()` consumes `ElectroSimTypography.apply(base.textTheme)`.
- Existing breakpoint API remains byte-for-byte behaviorally identical.

- [ ] **Step 1: Write failing Dart token-contract tests**
  Assert:
  - every Figma-mapped color has exact `Color.value`;
  - spacing/radii/geometry/motion values equal the approved mapping;
  - minimum touch target ≥ 48;
  - electrical colors remain distinct from semantic UI colors;
  - typography role sizes/weights/line heights equal mapping;
  - breakpoints still classify 390 compact, 820 medium, 1440 expanded.

- [ ] **Step 2: Verify RED**
  Run from `packages/electrosim_ui_kit`:
  `flutter test test/f18_g1_token_contract_test.dart`.
  Expected: FAIL on missing new token classes or mismatched mapped values.

- [ ] **Step 3: Implement the minimal token changes**
  Keep existing public names where already consumed. Add new focused files rather than moving unrelated widgets.

- [ ] **Step 4: Update theme consumption**
  Replace ad-hoc typography overrides in `ElectroSimTheme.light()` with `ElectroSimTypography.apply`; retain Material 3 and existing control themes unless Figma mapping explicitly changes them.

- [ ] **Step 5: Verify GREEN**
  Run:
  `flutter test test/f18_g1_token_contract_test.dart test/design_system_test.dart`.
  Expected: PASS.

- [ ] **Step 6: Analyze UI kit**
  Run: `flutter analyze` in `packages/electrosim_ui_kit`.
  Expected: no issues.

- [ ] **Step 7: Commit**
  Commit message: `F18-G1: synchronize qualified design tokens into UI kit`.

### Task 8: Add G1 CI gate, full regression and report

**Files:**
- Create: `.github/workflows/f18-g1-design-system.yml`
- Modify: `tools/f18_g1_design_system.py`
- Modify: `tools/test_f18_g1_design_system.py`
- Create: `docs/f18/g1/F18_G1_REPORT.md`
- Modify: `docs/f18/g1/F18_G1_EXECUTION_LEDGER.md`

**Interfaces:**
- Gate marker: `F18_G1_DESIGN_SYSTEM_GATE_PASS`.
- Allowed production source changes: `packages/electrosim_ui_kit/lib/**` only.
- Allowed support changes: `docs/f18/g1/**`, G1 spec/plan, `tools/f18_g1_*`, UI kit tests, G1 workflow.

- [ ] **Step 1: Write failing drift-guard tests**
  Assert protected runtime/core files are rejected and UI kit paths are accepted.

- [ ] **Step 2: Verify RED**
  Run targeted Python tests. Expected: FAIL until G1 drift guard is complete.

- [ ] **Step 3: Implement drift guard**
  Compare `main@591b8d6386de36093ed22deaab785c38245f5331...HEAD`; reject all product source outside UI kit.

- [ ] **Step 4: Create G1 workflow**
  Workflow steps, in order:
  1. checkout full history;
  2. Flutter 3.38.10;
  3. verify Dart 3.10.9;
  4. Python G1 tests;
  5. token mapping `--check`;
  6. drift guard;
  7. UI kit `flutter pub get` with lock drift check if lock exists;
  8. UI kit `flutter analyze`;
  9. UI kit full tests;
  10. app `flutter pub get` with lock drift check;
  11. app `flutter analyze`;
  12. app full `flutter test`;
  13. verify four reference PNGs + visual approval marker;
  14. echo final gate marker;
  15. upload G1 evidence.

- [ ] **Step 5: Run the exact-head workflow**
  Expected: all steps PASS and final marker emitted.

- [ ] **Step 6: Produce report from committed evidence**
  Report exact Figma fileKey, page/frame IDs, token counts, component counts, reference images, Flutter test counts, CI run ID, head SHA and artifact SHA-256.

- [ ] **Step 7: Request final code/design review**
  Review scope:
  - spec coverage;
  - Figma editability and no flattened full-screen captures;
  - token mapping completeness;
  - accessibility ratios;
  - no product source outside UI kit;
  - no runtime/motor modifications;
  - exact-head CI evidence.

- [ ] **Step 8: Resolve Critical/Important findings**
  Re-run affected Figma validation, tests and complete CI after every fix.

- [ ] **Step 9: Final exact-head verification**
  Expected marker: `F18_G1_DESIGN_SYSTEM_GATE_PASS`.

- [ ] **Step 10: Hand off to finishing-a-development-branch**
  Create/merge PR only after fresh green evidence; then G2 planning starts from integrated `main`.

---

## Execution Notes

- Execution method already selected by the user for F18: **Subagent-driven**.
- If the harness still exposes no actual subagent-dispatch primitive, use the official Superpowers `executing-plans` fallback and record that limitation in the G1 ledger; do not claim independent subagent reviews.
- Figma mutations are sequential, not parallel.
- Every Figma mutation returns all created/mutated IDs and immediately updates the external ledger.
- Stop at the Task 5 visual checkpoint for the single required human approval; otherwise execute autonomously.
