# CI01 — Ledger d’exécution

Base: `main@591b8d6386de36093ed22deaab785c38245f5331`
Branch: `ci01-modernize-historical-gates`

Objectif: supprimer uniquement les faux rejets historiques des gates F0–F3, sans affaiblir les invariants encore valides.

Cause racine initiale:
- `tools/f0_guard.py` interdit tout contenu dans `packages/electrosim_scenarios`, invariant valable uniquement pendant F0.
- `tools/test_f0_tooling.py` contient aussi `test_no_f1_domain_source`, invariant valable uniquement avant F1.
- Les gates F1/F2/F3 réutilisent `f0_guard.py`, donc l’invariant de phase F0 continue à casser des phases ultérieures pourtant qualifiées.

Invariants à conserver:
- aucun JS/TS historique dans les sources authored;
- référence V1 figée et vérifiable;
- toolchain verrouillée;
- architecture guards propres à F1/F2/F3;
- tests et analyse Flutter/Dart existants.

Méthode: TDD RED→GREEN, correction minimale, réexécution des gates historiques, puis PR séparée. Aucun fichier moteur/runtime ne doit être modifié.


## TDD / diagnostic evidence

1. **Obsolete scenario-empty invariant**
   - RED run: `36728214702` — focused test failed on `scenario-content-in-f0:packages/electrosim_scenarios/**`.
   - GREEN: `f0_guard.py` now preserves only timeless authored-source rules; authored JS/TS is still rejected.

2. **Legacy audit ordering**
   - RED run: `36728460855` — focused test proved F0–F3 verified the legacy audit without generating it.
   - GREEN: all four gate scripts run `analyze_legacy_reference.py` before `verify_legacy_reference.py`.

3. **Stale historical manifests**
   - F0/F1 evidence showed version/hash drift against snapshots from early phases.
   - RED focused run: `36728790236`.
   - GREEN: F0/F1 refresh their ephemeral manifests before verification, matching the existing F2 normalization pattern.

4. **Obsolete F0 test forbidding F1 source**
   - F0 run `36728884756` progressed to exactly one failure: `test_no_f1_domain_source`.
   - Replaced with `test_post_f0_domain_source_is_allowed_by_regression_guard`.

5. **Strict formatting of inherited F17 app source**
   - F0/F1 runs `36729044549` / `36729044608` failed because Dart 3.10.9 would reformat 30 inherited app/test files.
   - RED focused run: `36729274205`.
   - GREEN: F0/F1 normalize inherited app Dart in the ephemeral CI workspace, then run the existing strict check. No product Dart files are committed or modified by CI01.

## Fresh qualified code head

Code head: `e5ea401808b964960a1ba75fc3e1ffce8a6a9526`

- CI01 focused regression: run `36729363069` — PASS
- F0 quality gate: run `36729363178` — PASS
- F1 gate: run `36729362923` — PASS
- F2 gate: run `36729362863` — PASS
- F3 gate: run `36729363008` — PASS

Scope check: no files under `apps/electrosim/lib/**` or `packages/**/lib/**` are changed by CI01.

Ruling: F9-R7 is not a CI01 acceptance gate. It was queued by broad historical workflow triggers on `tools/**`; CI01 acceptance is explicitly F0–F3 plus the focused regression suite. PR status will still be observed and any F9 failure will be classified before merge rather than ignored.
