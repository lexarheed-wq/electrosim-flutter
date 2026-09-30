# ElectroSim F18 G0 Baseline & Parity Inventory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Figer l'état F17 qualifié et produire une matrice de parité V1→Flutter exhaustive, vérifiable et machine-lisible avant toute modification produit.

**Architecture:** G0 est documentaire et outillage uniquement : il ne modifie aucun package Flutter ni le runtime. Des scripts Python déterministes vérifient la référence V1, capturent la baseline F17, inventorient l'état Flutter actuel et valident une matrice de parité dont chaque entrée legacy reçoit une disposition explicite `REBUILD|REPLACE|DEFER|RETIRE`.

**Tech Stack:** Python 3 stdlib, CSV/JSON/Markdown, GitHub Actions, Flutter 3.38.10 / Dart 3.10.9 pour la régression de non-modification.

**Spec:** `docs/superpowers/specs/2026-09-30-electrosim-f18-product-parity-design.md`

## Global Constraints

- Base : `main@554d156839418f2be690980fe8acb941f776a425`.
- VERSION attendu au départ : `ELECTROSIM2-F17-R12-QUALIFIED`.
- Référence V1 : `reference/legacy/ElectroSim-FIELDFIX01-R1.zip`, SHA déjà contrôlé par `reference/REFERENCE_BASELINE.json`.
- Aucun fichier sous `packages/**/lib` ou `apps/electrosim/lib` n'est modifié par G0.
- Aucun élément legacy n'est importé automatiquement dans le catalogue Flutter.
- Toute sortie générée est déterministe : mêmes entrées = mêmes octets hors timestamp interdit.
- La matrice finale ne contient aucun statut `UNREVIEWED`.

## Review Focus

1. **Reference V1 corrompue ou remplacée** : le test propriétaire doit échouer sur SHA différent avant toute génération.
2. **ID legacy dupliqué** : le générateur doit refuser la matrice et nommer les IDs en conflit.
3. **Ligne legacy oubliée** : le gate doit prouver que les 217 entités sont présentes exactement une fois.
4. **Disposition invalide ou non justifiée** : le gate doit refuser toute valeur hors `REBUILD|REPLACE|DEFER|RETIRE` et toute justification vide.
5. **Drift F17 pendant G0** : le gate doit échouer si un fichier runtime/core est modifié ou si VERSION/toolchain diffère de la baseline.

---

## File structure

**Create**
- `docs/f18/g0/F18_G0_BASELINE.json` — snapshot machine-lisible du F17 protégé.
- `docs/f18/g0/F18_G0_BASELINE.md` — résumé humain du snapshot.
- `docs/f18/g0/F18_PRODUCT_PARITY.csv` — une ligne par entité legacy.
- `docs/f18/g0/F18_PRODUCT_PARITY.md` — synthèse par catégorie/disposition.
- `docs/f18/g0/F18_CAPABILITY_PARITY.csv` — capacités produit V1↔Flutter hors composants.
- `docs/f18/g0/F18_G0_REPORT.md` — résultat final et compteurs.
- `tools/f18_g0_capture_baseline.py` — capture/validation F17.
- `tools/f18_g0_build_parity.py` — parse, validate et synthétise les matrices.
- `tools/test_f18_g0_tooling.py` — tests unitaires Python.
- `.github/workflows/f18-g0-baseline-inventory.yml` — gate CI G0.

**Read only**
- `reference/REFERENCE_BASELINE.json`
- `reference/legacy/ElectroSim-FIELDFIX01-R1.zip`
- `docs/f0/legacy_component_inventory.csv`
- `docs/f0/LEGACY_FUNCTIONAL_INVENTORY.md`
- `docs/f9/F9_LEGACY_VISUAL_TAXONOMY.csv`
- `docs/f9/reference_screens/*`
- `apps/electrosim/lib/f9_component_palette.dart`
- `packages/electrosim_scenarios/lib/src/f16_catalog.dart`
- `ci/TOOLCHAIN_LOCK.json`
- `VERSION`

### Task 1: Freeze the F17 baseline

**Files:**
- Create: `tools/f18_g0_capture_baseline.py`
- Create: `tools/test_f18_g0_tooling.py`
- Create: `docs/f18/g0/F18_G0_BASELINE.json`
- Create: `docs/f18/g0/F18_G0_BASELINE.md`

**Interfaces:**
- Produces: `capture_baseline(root: pathlib.Path) -> dict[str, object]`
- Produces CLI: `python3 tools/f18_g0_capture_baseline.py [--check]`

- [ ] **Step 1: Write failing tests**
  - `test_capture_baseline_requires_f17_version`
  - `test_capture_baseline_requires_locked_flutter_3_38_10_dart_3_10_9`
  - `test_capture_baseline_records_legacy_sha_and_reference_paths`
  - `test_capture_baseline_is_deterministic`
  Assertions fixent VERSION, Flutter/Dart, legacy SHA and absence de timestamp.

- [ ] **Step 2: Verify RED**
  Run: `python3 -m unittest tools.test_f18_g0_tooling -v`  
  Expected: FAIL because `f18_g0_capture_baseline` does not exist.

- [ ] **Step 3: Implement minimal baseline capture**
  Read only `VERSION`, `ci/TOOLCHAIN_LOCK.json`, `reference/REFERENCE_BASELINE.json`, Git metadata supplied through CLI/env; write stable-key JSON and Markdown without current time.

- [ ] **Step 4: Verify GREEN**
  Run: `python3 -m unittest tools.test_f18_g0_tooling -v`  
  Expected: all Task 1 tests PASS.

- [ ] **Step 5: Generate committed baseline**
  Run: `python3 tools/f18_g0_capture_baseline.py`  
  Expected: prints `F18_G0_BASELINE_PASS`.

- [ ] **Step 6: Commit**
  Commit message: `F18-G0: freeze qualified F17 baseline`.

### Task 2: Build a deterministic current-Flutter inventory

**Files:**
- Modify: `tools/f18_g0_build_parity.py`
- Modify: `tools/test_f18_g0_tooling.py`
- Create: `docs/f18/g0/F18_CURRENT_PRODUCT_INVENTORY.json`

**Interfaces:**
- Produces: `extract_palette_definitions(dart_source: str) -> list[dict[str, str]]`
- Produces: `extract_catalog_counts(dart_source: str) -> dict[str, int]`
- Produces modelType set from `f9PaletteCatalog` without executing Flutter.

- [ ] **Step 1: Write failing tests**
  - exact current palette count = 12;
  - unique `keyName` and `modelType` extraction;
  - detects 5 qualified examples and 3 fault scenarios from current catalog evidence;
  - refuses duplicate palette keys.

- [ ] **Step 2: Verify RED**
  Run: `python3 -m unittest tools.test_f18_g0_tooling.F18G0ParityTests -v`  
  Expected: FAIL.

- [ ] **Step 3: Implement extractor**
  Parse only stable source constructs needed by G0; no Dart AST dependency is introduced.

- [ ] **Step 4: Verify GREEN**
  Same command; Expected: PASS.

- [ ] **Step 5: Commit**
  Commit message: `F18-G0: inventory current Flutter product surface`.

### Task 3: Create the exhaustive component parity matrix

**Files:**
- Modify: `tools/f18_g0_build_parity.py`
- Modify: `tools/test_f18_g0_tooling.py`
- Create: `docs/f18/g0/F18_PRODUCT_PARITY.csv`
- Create: `docs/f18/g0/F18_PRODUCT_PARITY.md`

**Interfaces:**
- Defines CSV columns exactly:
  `legacy_id,label,entity_class,legacy_category,legacy_modes,flutter_model_type,disposition,reason,target_gate,visual_family`
- Accepted dispositions: `REBUILD|REPLACE|DEFER|RETIRE`.
- Produces: `validate_parity(rows: list[dict[str,str]]) -> list[str]`.

- [ ] **Step 1: Write failing validation tests**
  - 217 rows exactly;
  - 195 `palette-component`, 4 `socket`, 18 `external-appliance`;
  - every `legacy_id` unique;
  - no `UNREVIEWED`;
  - every disposition valid;
  - `reason`, `target_gate`, `visual_family` non-empty;
  - any populated `flutter_model_type` must exist in current Flutter inventory or be marked as planned `REBUILD` with target gate G4/G5.

- [ ] **Step 2: Verify RED**
  Run: `python3 -m unittest tools.test_f18_g0_tooling.F18G0ParityMatrixTests -v`  
  Expected: FAIL because matrix does not exist.

- [ ] **Step 3: Generate seed matrix**
  Join `legacy_component_inventory.csv` with `F9_LEGACY_VISUAL_TAXONOMY.csv`; preserve all 217 rows and initialize explicit review fields.

- [ ] **Step 4: Adjudicate every row**
  Assign one of REBUILD/REPLACE/DEFER/RETIRE with a concrete reason and target gate. Do not infer automatic import. Preserve 103-family/category knowledge separately from the 217 entity count.

- [ ] **Step 5: Verify GREEN**
  Same unit command plus `python3 tools/f18_g0_build_parity.py --check`.  
  Expected: `F18_G0_PRODUCT_PARITY_PASS rows=217`.

- [ ] **Step 6: Commit**
  Commit message: `F18-G0: classify legacy component parity`.

### Task 4: Create capability parity outside the component catalog

**Files:**
- Modify: `tools/f18_g0_build_parity.py`
- Modify: `tools/test_f18_g0_tooling.py`
- Create: `docs/f18/g0/F18_CAPABILITY_PARITY.csv`

**Interfaces:**
- CSV columns: `capability,legacy_evidence,flutter_evidence,current_state,target_gate,acceptance`.
- `current_state`: `PRESENT|PARTIAL|MISSING|INTENTIONALLY_REDESIGNED`.

- [ ] **Step 1: Write failing tests**
  Matrix must contain at least: accueil, session, maintenance, conception, palette, canvas, câblage, mesures, énergie, EIE, sauvegarde, TP câblage, RD, supervision, mobile/responsive, LAN.
  Every row requires non-empty legacy evidence, Flutter evidence, target gate and acceptance criterion.

- [ ] **Step 2: Verify RED**
  Run targeted unittest; Expected: FAIL.

- [ ] **Step 3: Build and review matrix**
  Seed from `LEGACY_FUNCTIONAL_INVENTORY.md`, `F9_LEGACY_VISUAL_AUDIT.md`, F17 status/runtime tests and current `main.dart`.

- [ ] **Step 4: Verify GREEN**
  Run targeted unittest; Expected: PASS.

- [ ] **Step 5: Commit**
  Commit message: `F18-G0: map product capability parity`.

### Task 5: Add the G0 CI gate and protected-file drift check

**Files:**
- Create: `.github/workflows/f18-g0-baseline-inventory.yml`
- Modify: `tools/f18_g0_capture_baseline.py`
- Modify: `tools/test_f18_g0_tooling.py`

**Interfaces:**
- CLI: `python3 tools/f18_g0_capture_baseline.py --check --base-sha <sha>`
- Gate marker: `F18_G0_BASELINE_INVENTORY_GATE_PASS`.

- [ ] **Step 1: Write failing drift tests**
  Test rejects changes under `packages/**/lib/**` or `apps/electrosim/lib/**` between base SHA and head during G0.

- [ ] **Step 2: Verify RED**
  Targeted unittest fails.

- [ ] **Step 3: Implement drift guard**
  Use `git diff --name-only <base>...HEAD`; allow only docs, tools, tests and G0 workflow paths.

- [ ] **Step 4: Configure CI**
  Workflow uses Python, verifies legacy SHA, runs all G0 tests/checks, then uses Flutter 3.38.10 to run:
  `flutter pub get`, `flutter analyze`, `flutter test` in `apps/electrosim`.
  It must verify `pubspec.lock` unchanged after pub get.

- [ ] **Step 5: Verify locally where possible**
  Run:
  `python3 tools/verify_legacy_reference.py`
  `python3 -m unittest tools.test_f18_g0_tooling -v`
  `python3 tools/f18_g0_capture_baseline.py --check`
  `python3 tools/f18_g0_build_parity.py --check`
  Expected: all PASS.

- [ ] **Step 6: Commit**
  Commit message: `F18-G0: enforce baseline and inventory gate`.

### Task 6: Produce G0 report and final verification

**Files:**
- Create: `docs/f18/g0/F18_G0_REPORT.md`

**Interfaces:**
- Report must name exact head SHA, exact row counts, disposition counts, current Flutter palette count, example/fault counts, CI run id and gate marker.

- [ ] **Step 1: Run full G0 workflow on exact branch head**
  Expected: Python checks PASS, Flutter analyze/test PASS, drift guard PASS.

- [ ] **Step 2: Generate report from committed machine-readable outputs**
  No manually typed counts except CI run id/head SHA.

- [ ] **Step 3: Request independent code review**
  Review scope: spec compliance, determinism, no product code changes, no missing legacy rows.

- [ ] **Step 4: Address every Critical/Important finding**
  Re-run full gate after fixes.

- [ ] **Step 5: Verify exact head**
  Expected marker: `F18_G0_BASELINE_INVENTORY_GATE_PASS`.

- [ ] **Step 6: Commit report**
  Commit message: `F18-G0: record qualified baseline and parity inventory`.

- [ ] **Step 7: Hand off to finishing-a-development-branch**
  Present merge/PR options only after fresh green verification.
