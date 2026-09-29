# Rapport F0 R4 — baseline technique complète et CI corrigée

Date : 27 septembre 2026  
Version : `0.0.0-f0-r4-candidate`  
Décision : **NO-GO vers F1 tant que la porte Flutter réelle n'est pas verte**

## Travaux R4

1. Ajout d'un analyseur statique reproductible du ZIP historique : `tools/analyze_legacy_reference.py`.
2. Génération d'une baseline machine-lisible : `audit/legacy_reference_analysis.json`.
3. Génération d'une synthèse documentaire : `docs/f0/LEGACY_TECHNICAL_BASELINE.md`.
4. Ajout d'un vérificateur non destructif : `tools/verify_legacy_reference.py`.
5. Intégration du contrôle de la référence historique dans la porte F0.
6. Extension des tests du tooling F0 pour vérifier la présence et la cohérence de la baseline legacy.
7. Correction du workflow GitHub Actions : les artefacts runtime sont désormais lus dans `audit/runtime/`, emplacement réellement utilisé par `run_f0_gate.sh`.
8. Conservation stricte de l'interdiction F1 : aucun fichier Dart métier n'a été ajouté dans `packages/electrosim_domain`.

## Résultats de la baseline historique

Référence contrôlée : `ElectroSim-FIELDFIX01-R1.zip`  
SHA-256 : `569e05908592e6dd615bd80b342f6c7a28249850951d353dac988c5d2e1187bd`

Analyse statique :

- 1 535 fichiers réels dans l'archive, hors entrées de répertoires ;
- 348 fichiers JavaScript ;
- 109 fichiers TypeScript ;
- 4 fichiers MJS ;
- 70 fichiers JSON ;
- 213 images PNG ;
- 461 fichiers JS/TS/MJS analysés ;
- `teacher.html` charge 137 scripts externes ;
- `student.html` charge 128 scripts externes ;
- environ 291 affectations explicites sur `window` / `globalThis` détectées ;
- environ 20 mutations de prototypes détectées ;
- environ 200 enregistrements `addEventListener` détectés.

Ces chiffres sont des signaux de structure, pas des preuves de comportement runtime. Ils confirment cependant quantitativement pourquoi le nouveau projet ne doit pas reproduire l'ordre de chargement historique, les globals et les monkey-patches.

## Vérification toolchain

Le lock reste :

- Flutter `3.47.5` ;
- Dart `3.13.4` ;
- stable ;
- révision Flutter `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`.

La métadonnée Linux officielle de Flutter confirme ce couple de versions et le SHA-256 Linux déjà enregistré dans le lock.

## Preuves exécutées dans ce runtime

- `f0_guard.py` : PASS ;
- `verify_legacy_reference.py` : PASS ;
- `validate_test_vectors.py` : PASS ;
- `test_f0_tooling.py` : **10/10 PASS** ;
- syntaxe Python des outils : PASS ;
- intégrité ZIP historique : PASS ;
- aucune migration d'ancien exemple/panne : PASS.

## Blocage restant

Le runtime courant ne possède toujours ni Flutter ni Dart et le shell ne peut pas résoudre le serveur de distribution Flutter. Les deux contrôles obligatoires suivants restent donc non exécutables ici :

- `flutter analyze` ;
- `flutter test`.

Le statut reste **BLOCKED / NO-GO**, pas PASS. F1 n'est pas ouvert.

## Prochaine action conforme

Exécuter `./tools/bootstrap_flutter_and_run_f0.sh` sur un environnement macOS/Linux ayant accès à Internet, ou exécuter le workflow GitHub Actions F0. Dès que le journal contient `F0_GATE_PASS`, F1 peut commencer.
