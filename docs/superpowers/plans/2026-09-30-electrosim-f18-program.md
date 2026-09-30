# ElectroSim F18 Program Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformer la couche produit Flutter en successeur de la V1, sans réécrire ni fragiliser le noyau F17 qualifié.

**Architecture:** F18 est un programme de 13 gates indépendants G0→G12. Chaque gate possède sa propre branche/worktree, son plan détaillé, ses tests, ses preuves et sa PR ; le gate suivant part uniquement de `main` après intégration du précédent. La V1 est un oracle fonctionnel/visuel et Figma devient la source de vérité visuelle, tandis que les packages cœur F17 restent protégés.

**Tech Stack:** Flutter 3.38.10, Dart 3.10.9, Python 3 pour audits/gates, GitHub Actions, Figma, Superpowers.

**Spec:** `docs/superpowers/specs/2026-09-30-electrosim-f18-product-parity-design.md`

## Global Constraints

- Base technique immuable au démarrage : `ELECTROSIM2-F17-R12-QUALIFIED`.
- Le code V1 ne devient jamais une dépendance runtime Flutter.
- L'UI ne calcule jamais les grandeurs électriques.
- Aucun composant décoratif n'est exposé comme simulable sans modèle moteur réel.
- Aucun golden n'est auto-accepté par CI.
- Toolchain : Flutter 3.38.10 / Dart 3.10.9.
- Les packages `domain`, `topology`, `solver_dc`, `solver_ac`, `pv`, `energy`, `measurements`, `diagnostics`, `tp`, `storage` sont protégés.
- Toute modification d'un package protégé exige test rouge, contrat documenté, gate moteur dédié et régression complète.
- Aucun merge avec finding Critique ou Important ouvert.
- Les validations physiques ne sont demandées que pour les comportements matériels non qualifiables de façon fiable en CI.

## Review Focus

1. Une amélioration visuelle ne doit jamais introduire une logique électrique dans l'UI ; le gate propriétaire ajoute un test d'absence de calcul/valeur fabriquée.
2. Une famille visible doit toujours être soutenue par un `modelType` et un contrat moteur ; G4/G5 ajoutent les tests catalogue↔runtime.
3. Les goldens ne doivent pas masquer une régression ; G1/G3 ajoutent baseline + candidate + diff et interdisent l'auto-update en CI.
4. Les parcours élève/professeur doivent rester isolés ; G8 teste rôles, teacher truth et lecture seule.
5. Le responsive doit préserver le Canvas ; G3/G11 testent compact 390×844, medium 820×1180, desktop 1440×900 et 1920×1080.

---

## Gate sequence

| Gate | Plan détaillé | Dépend de | Livrable testable |
|---|---|---|---|
| G0 | `2026-09-30-electrosim-f18-g0-baseline-inventory.md` | F17-R12 | baseline figée + matrice de parité exhaustive |
| G1 | à écrire après G0 intégré | G0 | design system Figma + tokens + frames de référence |
| G2 | à écrire après G1 intégré | G1 | product shell/navigation sans shell demo |
| G3 | à écrire après G2 intégré | G2 | workspace scaffold responsive |
| G4 | à écrire après G3 intégré | G3 | visual framework + 20 familles critiques |
| G5 | à écrire après G4 intégré | G4 | catalogue supporté traité exhaustivement |
| G6 | à écrire après G5 intégré | G5 | canvas/câblage/gestes/performance |
| G7 | à écrire après G6 intégré | G6 | instruments + propriétés réels |
| G8 | à écrire après G7 intégré | G7 | cycle TP professeur/élève complet |
| G9 | à écrire après G8 intégré | G8 | bibliothèques saines/pannes et couverture pédagogique |
| G10 | à écrire après G9 intégré | G9 | EIE produit teacher, silence si OK |
| G11 | à écrire après G10 intégré | G10 | polish responsive/a11y/performance |
| G12 | à écrire après G11 intégré | G11 | 5 builds release + validation physique Mac |

### Task 1: Qualifier G0
- [ ] Exécuter intégralement le plan G0.
- [ ] Faire une revue de code indépendante de la branche G0.
- [ ] Vérifier le gate G0 sur le head exact.
- [ ] Créer une PR G0 vers `main`; ne fusionner qu'après gate vert et revue propre.
- [ ] Écrire le plan G1 à partir du `main` résultant.

### Task 2: Qualifier G1→G11
Pour chaque gate, répéter strictement :
- [ ] Explorer le `main` intégré et écrire le plan détaillé du gate.
- [ ] Créer un worktree/branche isolé.
- [ ] Exécuter TDD tâche par tâche.
- [ ] Revue indépendante après chaque tâche significative.
- [ ] Gate complet + preuves + artefacts.
- [ ] PR vers `main`, merge seulement si Critique/Important = 0.
- [ ] Écrire le plan du gate suivant seulement après intégration.

### Task 3: Qualifier G12
- [ ] Exécuter régression complète sur le head final.
- [ ] Produire builds release Linux/Windows/Android/macOS/iOS avec SHA-256.
- [ ] Vérifier permissions/configuration LAN générées.
- [ ] Exécuter les tests perf/a11y/goldens finaux.
- [ ] Fournir un paquet Mac basé sur le head qualifié.
- [ ] Demander uniquement la validation physique trackpad/rendu/LAN.
- [ ] N'émettre `F18_PHYSICAL_MAC_PASS` qu'après confirmation physique.
