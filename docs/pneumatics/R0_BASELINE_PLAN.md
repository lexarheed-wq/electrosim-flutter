# ElectroSim — R0, plan d'exécution et protocole de référence
Date : 2026-10-10 — Directeur PNEU-DIR-001 v1.0

## But et périmètre
Établir une référence **reproductible** et un état contrôlé avant tout changement des contrats électriques. Ce lot **n'implémente pas** le solveur pneumatique. Il vérifie une base candidate, les chemins existants, les versions, la régression et les scénarios de performance. Sortie : SHA R0 réellement testé, résultats/limites, budgets et décision documentée.

## Source et base candidate
- Directeur original : branche `docs/pneumatic-program-director-20261010`, commit `8b10c9e683239e13a3186c7b4a3a944e1cac4d75`, blob `aed1b6637e71f49c0161cba146e2dbb6e82c3aa6`.
- Base G5 retenue **pour évaluation R0** : `feat/g5-industrial-geometry-20261009` au SHA `054c64f5d2c74bf9a7137c730b811968834543ee`. Les PR #72, #74–#77 sont intégrées à cette branche ; #73 et #78 sont ouvertes et non retenues.
- Départ G5 (avant nouveaux commits R0) : quatre jobs **success** (`runtime-regression`, `visual-evidence`, `tp-browser-journey`, `macos-intel`), https://github.com/lexarheed-wq/electrosim-flutter/actions/runs/38074446746 ; ces résultats ne portent que sur le SHA G5 ci-dessus, et n'ont pas valeur de qualification R0.
- Branche R0 isolée : `docs/pneumatic-r0-baseline-20261010`; cible de revue : G5 (jamais `main` qui diverge historiquement). Ne pas toucher à P4 actif.

## Constat initial vérifié sur G5
- `SavedCircuitDocument.currentSchemaVersion == 2` dans `packages/electrosim_storage/lib/src/storage_models.dart` ; migrations v0/v1 vers v2 et rejet explicite des versions non reconnues.
- `CircuitState` électrique et `ElectricalMode` doivent demeurer inchangés en R0.
- L'app utilise Dart >=3.10.0, Flutter 3.38.10 pour les workflows courants.
- Le branchement pneumatique **n'existe pas** sur G5 : pas de packages `electrosim_pneumatic_domain`, `electrosim_pneumatic_solver` ni `electrosim_multiphysics`. Aucune promesse de calcul pneumatique réel en R0.
- Prise en compte des fonctions existantes de platine/schéma, de P3 et de la persistance.

## Modifications autorisées et fichiers exacts
1. Copier **sans modifier** le directeur dans `docs/superpowers/specs/2026-10-10-electrosim-pneumatique-document-directeur.md`.
2. Ajouter `docs/pneumatics/PROGRAM_STATUS.md`.
3. Ajouter ce plan `docs/pneumatics/R0_BASELINE_PLAN.md`.
4. Ajouter `docs/pneumatics/qualification/R0/BASELINE_MANIFEST.md` et le rapport après observation des contrôles.
5. Ajouter `.github/workflows/pneumatics-r0-baseline.yml` : CI sur la branche R0 / PR vers G5 sans mutation de goldens, commandes et provenance reproductibles.
6. Éventuellement ajouter des **scénarios de mesure non destructifs** en R0 si leurs méthodes et machines sont décrites préalablement.
Aucun changement de runtime, stockage, contrat, palette, moteur électrique, rendu ou assets.

## Contrats consommés et invariants
- `apps/electrosim/lib/main.dart` = point d'entrée production.
- `CircuitState` et anciens documents v0/v1/v2 lisibles comme avant.
- Fil électrique et tuyau pneumatique restent des domaines distincts à partir de R1 ; aucune adaptation d'un `ElectricalMode` en R0.
- Aucun dossier `docs/pneumatics/qualification/R0` ne constitue une preuve tant qu'il ne référence pas le commit testé et les jobs complétés.

## Contrôles R0
1. Vérifier le SHA exact en checkout ; `git diff --check`.
2. Exécuter `python3 tools/core_unify_architecture_guard.py`, `python3 tools/postv2_p1_contract.py`.
3. Exécuter l'analyse Flutter, les tests app et Canvas, puis les tests par packages affectés ou liés (domaine, topologie, solveurs DC/AC et stockage). Installer les dépendances pour chacun et archiver les logs.
4. Exécuter les builds adaptés uniquement quand l'entrée production, la plateforme et la commande ont été identifiées ; distinguer compilation et lancement.
5. Enregistrer machine, CPU, RAM, OS, Flutter/Dart, locale, navigateur, display, commande, SHA, sortie, résultat, date.
6. Décrire trois scénarios électriques de régression CC/AC1/AC3/PV : sources à vide/en charge, instruments/protections, et séquences contacts ; **ne pas** déduire des résultats des tests dont le journal n'est pas disponible.
7. Geler le manifeste des futurs scénarios 30/100/200/400 : appareils électriques/pneumatiques, ports, tuyaux, volumes, vérins mobiles et commutations. La référence R0 électrique seule ne permet pas encore de mesurer les deux autres familles.
8. Pour les mesures futures : préchauffage 10 s, acquisition 60 s, trois répétitions, p50/p95/max (clic, calcul, frames, publication), mémoire/objets retenus, time drift ; les chiffres restent `non_mesuré` tant que les journaux bruts ne sont pas produits.
9. Exiger des preuves CI issues **du SHA exact du lot**, non des anciennes PR. Tout merge/rebase impose de recommencer la qualification.

## Critères de sortie R0
- SHA testé et version outil identifiés.
- Journaux verts sur le commit **R0** ou défaut décrit et traité, sans suppression de tests/goldens.
- Baseline et limites consignées. Matrice 30/100/200/400 gelée avec manifeste (benchmarks numériques peuvent rester ouverts si aucun banc réel n'est disponible, et doivent être classés explicitement).
- Décision documentée d'aptitude de la base à R1 et conflits de PR #73/#78 vérifiés.
- Pas de mise en œuvre R1 tant que les prérequis bloquants ne sont pas levés.

## Risques et arbitrages
- Les PR #73 et #78 ouvertes peuvent modifier la base : mise à jour coordonnée, revue des conflits, nouveaux checks sur le SHA intégré.
- La CI historique G5 met à jour des goldens pour fabriquer des preuves ; le nouveau workflow ne doit ni réécrire ni committer de goldens.
- L'environnement local de ce travail ne possède pas Flutter/Dart ni de clone du dépôt ; seules les vérifications constatées dans GitHub pourront être qualifiées.
- Les objectifs `400 composants` restent une cible à mesurer, pas une capacité démontrée.
- R1 doit décider les contrats exacts et la version de sauvegarde après comparaison de la base retenue.

## Retour arrière
Ne supprimer que la branche/PR R0 si nécessaire ; aucun fichier métier de G5 n'est modifié. Conserver les rapports dans la PR ou les artefacts de CI. Aucune fusion automatique, aucune publication, aucune modification de l'historique de G5.

## Gate vers R1
R1 exige : rapport R0 qualifié (ou dérogation formalisée acceptée), contrats de ports/liens/identité approuvés, stratégie de migration v0/v1/v2 testable, CI de régression reproductible. Le plan R1 sera distinct et précis avant toute implémentation.
