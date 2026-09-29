# Rapport F0 R3 — intégrité renforcée du laboratoire

Date: 27 septembre 2026  
Version: `0.0.0-f0-r3-candidate`  
Décision: **NO-GO vers F1 tant que la porte Flutter réelle n'est pas verte**

## Corrections / renforcements R3

1. Verrouillage machine-lisible du toolchain : Flutter 3.47.5 / Dart 3.13.4.
2. SHA-256 des archives Flutter contrôlé avant extraction pour Linux x64, macOS Intel et macOS Apple Silicon.
3. Manifest F0 régénérable et vérifiable avec SHA-256 par fichier.
4. Validation cumulative du corpus de vecteurs : présence des cas canoniques, IDs uniques, SA-01..SA-10, JSON valide, interdiction des couplages legacy.
5. Le gate F0 exécute désormais les gardes Python, le validateur de vecteurs, le manifest et les tests du tooling avant Flutter.
6. Les sorties runtime sont isolées sous `audit/runtime/` et n'altèrent pas le manifest candidat.
7. Le gate vérifie que la version Flutter réellement utilisée est exactement celle du lock.

## Preuves exécutées dans ce runtime

- `f0_guard.py` : PASS.
- `validate_test_vectors.py` : PASS.
- `verify_f0_manifest.py` : PASS après génération du manifest.
- `test_f0_tooling.py` : PASS.
- compilation syntaxique des scripts Python : PASS.
- intégrité du ZIP historique : PASS via garde F0.

## Blocage restant

Le runtime d'exécution actuel n'expose pas de SDK Flutter/Dart et son réseau shell ne résout pas le dépôt de distribution Flutter. `flutter analyze` et `flutter test` ne peuvent donc pas être exécutés ici. Cette absence est traitée comme **BLOCKED**, jamais comme PASS.

Aucune classe de domaine F1 n'est ajoutée dans ce candidat.
