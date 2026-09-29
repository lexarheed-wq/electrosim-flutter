# Rapport F8-R2 — Compatibilité des API pointeur Flutter 3.38.10

## Déclencheur

La première exécution physique de F8-R1 sur le Mac Monterey validé a atteint `flutter analyze` du package `electrosim_canvas` puis s'est arrêtée avant les tests widget.

L'analyseur a signalé quatre symboles d'entrée non résolus :

- `PointerSignalEvent` ;
- `PointerScrollEvent` ;
- `PointerHoverEvent` ;
- `PointerDeviceKind` dans le test de molette.

Il a également signalé trois informations de lint : directive `library` inutile et deux imports `dart:ui` inutiles dans les tests.

## Cause racine

F8-R1 utilisait des classes de la couche Flutter Gestures sans importer explicitement `package:flutter/gestures.dart`. Les imports `material.dart` / `flutter_test.dart` ne constituent pas un contrat fiable pour exposer ces types sous le toolchain verrouillé Flutter 3.38.10.

Il s'agit d'un défaut de compilation/analyse de la couche Canvas, pas d'un défaut du noyau électrique F1→F7.

## Correction minimale

- ajout explicite de `package:flutter/gestures.dart` dans `simulator_canvas.dart` ;
- ajout explicite de `package:flutter/gestures.dart` dans `simulator_canvas_test.dart` ;
- suppression de la directive `library electrosim_canvas;`, devenue inutile ;
- suppression des imports `dart:ui` redondants dans `hit_test_engine_test.dart` et `viewport_controller_test.dart` ;
- renforcement du contrôle statique F8 pour empêcher la réapparition de ces incohérences d'import.

Aucun algorithme de rendu, aucune interaction, aucune règle électrique et aucun solveur n'a été modifié.

## Statut

F8 reste **CANDIDAT**. La validation physique doit reprendre avec `./validate.sh` et atteindre `F8_GATE_PASS`.
