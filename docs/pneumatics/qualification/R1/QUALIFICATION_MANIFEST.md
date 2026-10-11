# R1 — Contrats et sauvegardes — Manifeste de qualification

Référentiel : PNEU-DIR-001 v1.0 (2026-10-10)
PR : https://github.com/lexarheed-wq/electrosim-flutter/pull/81
Branche de destination : `feat/g5-industrial-geometry-20261009`.

## Prérequis
- R0 PR #79 fusionnée au SHA `2f0c1fb561e75a8cff3973b561835b2505283453`.
- Référence G5 antérieure `054c64f5d2c74bf9a7137c730b811968834543ee`.
- Les quatre jobs principaux R0 (contrats et science, app/Canvas, compilation Web, banc CC de référence) sont verts au SHA R0 pré-fusion `fcc81f4149860f251e41f918a3b95d5488966cd4`.
- Ne pas confondre la qualification du banc électrique seul avec celle d'une simulation pneumatique.

## Livraisons de R1
- Package `electrosim_pneumatic_domain` : modèle de port typé `PneumaticPortId`, appareil, tuyau et réseau; paramètres SI, validations, JSON et diagnostics d'erreurs explicites.
- Package `electrosim_multiphysics` : identité physique, liens de bobines/contacts, positions des deux vues et vérification de l'association explicite.
- Extension ajoutée à `electrosim_storage`, sans modification de l'ancien décodeur : nouvelle enveloppe v3 et migrations v0–v2 sans perte des paramètres électriques ; refus d'export ancien pour les projets mixtes.
- `apps/electrosim/lib/runtime/pneumatic_feature_gate.dart` : famille électrique/pneumatique/électropneumatique distincte de `ElectricalMode`, expérimentale et OFF par défaut. Cela ne signifie pas encore qu'un atelier complet R4 existe.
- Tests unitaires Dart (tuyaux, topologie, registres, identité, migration et refus de pertes), test du feature gate et workflow GitHub CI.

## Contrôles requis avant fusion
- PNEU-R1 `pneumatic-contracts` (analyse/test de trois packages et test widget du feature gate) sur le SHA exact de la PR.
- F0, F1 et G5 régression produit sur le même arbre final de revue ; contrôles verts ou réserves explicites acceptées.
- Vérifier `git diff --check`, absence de formatage en attente, aucune mutation des solveurs électriques, aucune correction d'assets/goldens.
- Vérifier les PR parallèles #73 et #78 avant fusion : pas de code P4 implicitement intégré.
- Après fusion, constater le commit d'intégration, relancer la qualification si l'arbre a changé et mettre à jour `docs/pneumatics/PROGRAM_STATUS.md`.

## Périmètre exact de R1
Ce lot est qualifiable pour ses **contrats et persistance**. Il n'est pas une livraison de simulation pneumatique complète : PHY/CPL/ERR/UI/PERF et Mac utilisateur restent ouverts. R2 est responsable de l'écoulement compressible, des mouvements de vérin et du temps physique ; R3 du couplage 24 V ; R4 des deux vues.

## État
**Implémenté en PR ; qualification du dernier arbre et intégration en attente.**
Aucun résultat de contrôle ne doit être affirmé s'il n'est pas disponible sur le commit précis. Aucune fusion d'une CI rouge ou inconnue.
