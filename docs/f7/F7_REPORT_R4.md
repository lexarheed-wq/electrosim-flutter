# Rapport F7-R4 — Fixture de température invalide compatible avec le contrat F1

## Défaut reproduit

La porte F7-R3 atteint les tests PV mais le test `invalid environmental settings fail explicitly` échoue avant l'appel au solveur lors de la construction de `CircuitState`.

Trace observée : `freezeJson` rejette `double.nan` avec `DomainException(invalidJsonValue)`.

Ce comportement du domaine est correct : depuis F1, tout état persistant doit être JSON-compatible et les nombres non finis (`NaN`, `Infinity`) sont interdits. Le test F7 essayait donc de créer un `CircuitState` invalide à un niveau plus bas que le solveur PV qu'il voulait tester.

## Cause racine

La fixture `invalidTemperatureSetting` plaçait `double.nan` dans `CircuitState.settings['cellTemperatureC']`. Le constructeur de `CircuitState` appelle `freezeJsonMap`, qui refuse les nombres non finis avant que `SolverPV._finiteSetting` puisse produire son diagnostic `invalidPvParameter`.

## Correction

La fixture utilise maintenant une valeur JSON valide mais sémantiquement invalide pour le solveur :

- avant : `double.nan` ;
- après : `'invalid-temperature'`.

Ainsi :

1. le contrat F1 reste strict et inchangé ;
2. `CircuitState` reste sérialisable ;
3. le test atteint réellement la validation F7 de `cellTemperatureC` ;
4. le solveur doit retourner un résultat `invalid` avec `PvDiagnosticCode.invalidPvParameter`.

Aucune équation PV, aucun seuil de couverture et aucun contrat F1-F6 n'est modifié.

## Critère

La porte F7 reste inchangée : tests PV verts, couverture F7-PV >= 90 %, puis `F7_GATE_PASS`.

## Statut

CANDIDAT. Validation réelle requise sur le toolchain Monterey verrouillé.
