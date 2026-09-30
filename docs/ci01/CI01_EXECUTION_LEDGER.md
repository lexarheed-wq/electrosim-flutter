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
