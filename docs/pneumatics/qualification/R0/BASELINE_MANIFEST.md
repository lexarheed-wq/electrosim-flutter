# R0 — Baseline manifest (provisional, NOT qualified)
Document directeur : PNEU-DIR-001 v1.0, 2026-10-10
Nom du lot : R0 — Référence électrique et compatibilité
Statut : EN COURS — aucune physique pneumatique implémentée.

## Références immuables
| Élément | Valeur |
| --- | --- |
| Dépôt | `lexarheed-wq/electrosim-flutter` |
| Base candidate (G5) | `054c64f5d2c74bf9a7137c730b811968834543ee` |
| Branche source | `feat/g5-industrial-geometry-20261009` |
| Branche R0 | `docs/pneumatic-r0-baseline-20261010` |
| Directeur original | `8b10c9e683239e13a3186c7b4a3a944e1cac4d75`, blob `aed1b6637e71f49c0161cba146e2dbb6e82c3aa6` |
| Tests de la base G5 | https://github.com/lexarheed-wq/electrosim-flutter/actions/runs/38074446746 — 4 jobs verts |
| SHA R0 testé | **NON RENSEIGNÉ : sera le SHA GitHub du dernier commit R0 après CI** |
| Statut tests R0 | **NON EXÉCUTÉS à la rédaction de ce manifeste** |
| Version Flutter/Dart CI ciblée | 3.38.10 / Dart embarqué avec Flutter ; vérifier `flutter --version` en logs |
| Plateformes validées sur SHA R0 | aucune |
| Limitations | environnements locaux sans Flutter ; pas de banc de référence pour 400 composants |
| Delta par rapport à G5 | documentation, plans, CI, aucune modification applicative |

## Lots de tests de référence
Les tests suivants sont **à exécuter sur le SHA R0**, sans déduire leur résultat des historiques G5 :
- Application : `flutter analyze`, `flutter test --no-pub --concurrency=1`.
- Canvas : `flutter analyze`, `flutter test --no-pub --concurrency=1`.
- Contrats et solveurs Dart : `dart test` dans `electrosim_domain`, `electrosim_topology`, `electrosim_solver_dc`, `electrosim_solver_ac`, `electrosim_storage`.
- Gardes : `python3 tools/core_unify_architecture_guard.py`, `python3 tools/postv2_p1_contract.py`, `git diff --check`.
- Entrée Web production : `flutter build web --release --target lib/main.dart --no-wasm-dry-run`. La compilation seule ne prouve pas un lancement.

## Matrice de charge à geler avant mesures
| Profil | Appareils | Électrique | Pneumatique | Mixte | Nombre de tuyaux/volumes/vérins | Résultat |
| --- | ---: | --- | --- | --- | --- | --- |
| S30 | 30 | préexistant à formaliser | hors R0 | hors R0 | non défini | non mesuré |
| S100 | 100 | préexistant à formaliser | hors R0 | hors R0 | non défini | non mesuré |
| S200 | 200 | préexistant à formaliser | hors R0 | hors R0 | non défini | non mesuré |
| S400 | 400 | préexistant à formaliser | hors R0 | hors R0 | non défini | non mesuré |

Ne pas inventer les nombres de nœuds, pressions ni benchmarks. Un scénario **électrique seul** doit disposer d'un état attendu déterministe, de métriques et d'une topologie gelée avant l'acquisition des résultats. Les scénarios air/mixte ne sont mesurables qu'après R2/R3.

## Budget cible (exigences non encore atteintes)
- Retour visuel connexion p95 ≤ 100 ms.
- ≥ 95 % des frames ≤ 16,7 ms après échauffement.
- Dérive temps simulé ≤ 100 ms sur 60 s réelles.
- Calcul de 100 ms de simulation / 400 composants p95 ≤ 80 ms hors thread UI.
- Surcoût p95 circuit électrique seul ≤ 10 % par rapport au baseline R0.
- Préchauffage 10 s, mesure 60 s, trois répétitions, médiane/p95/max et suivi mémoire.

## Limitations ouvertes
1. Pas de benchmark brut 30/100/200/400 exécuté à ce stade.
2. Pas d'exécution physique pneumatique, donc pas de valeur PHY/CPL.
3. PR #73 / #78 peuvent nécessiter rebase / nouvelle qualification de la base.
4. Contrôles vérifiés de G5 ne dispensent pas de CI sur le SHA R0.
5. Aucun chemin `main` ou release modifié et aucune fusion implicite.

## Conditions de mise à jour
L'exécutant complète le SHA du **lot** et des jobs, ajoute les liens vers artefacts et résultats bruts, puis attribue `qualifié` uniquement si le gate et ses écarts sont effectivement traités. Pas de capture inventée, pas de golden régénéré automatiquement.
