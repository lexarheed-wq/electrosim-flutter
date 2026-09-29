# F9-R12 — correction du gate d’analyse

## Symptôme observé sur Mac

`flutter analyze` s’arrêtait sur `apps/electrosim/test/f9_auto_placement_test.dart:39:18` avec `unnecessary_non_null_assertion`.

## Cause

Le test avait déjà établi/utilisé `result` comme non nul et appliquait encore `result!.dy`. L’analyseur Dart considère ce `!` comme redondant.

## Correction

`result!.dy` devient `result.dy`. Aucun code de production n’est modifié.

## Invariants

- moteur de placement automatique R11 inchangé ;
- `CircuitState` inchangé ;
- Canvas F8 inchangé ;
- solveurs inchangés.

## Gate attendu

`F9_R12_GATE_PASS`
