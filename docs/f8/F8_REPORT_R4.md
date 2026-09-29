# Rapport F8-R4 — Compatibilité PointerScrollEvent Monterey

## Déclencheur

L’exécution physique de F8-R3 sur Flutter 3.38.10 / Dart 3.10.9 a franchi les régressions F1 à F7 puis s’est arrêtée à `F8-flutter-analyze`.

Erreur observée :

`The named parameter 'pointer' isn't defined` dans `test/simulator_canvas_test.dart`.

## Cause racine

La fixture de test créait `PointerScrollEvent(pointer: 1, ...)`. Le constructeur public disponible dans le toolchain Monterey verrouillé ne définit pas ce paramètre nommé. L’événement de molette n’a pas besoin de cet argument pour tester le zoom autour de la position fournie.

## Correction minimale

- suppression de `pointer: 1` dans la construction de `PointerScrollEvent` du test de molette ;
- conservation de `position` et `scrollDelta` ;
- ajout d’une garde statique interdisant la réintroduction de cet argument incompatible ;
- aucune modification du code de production du Canvas ;
- aucune modification du noyau, des solveurs ou des résultats électriques.

## Critère de non-régression

`flutter analyze` du package `electrosim_canvas` doit franchir cette fixture sous Flutter 3.38.10, puis les tests de gestes et les goldens peuvent s’exécuter.

## Statut

F8 reste **CANDIDAT** jusqu’à obtention de `F8_GATE_PASS` sur le Mac Monterey de validation.
