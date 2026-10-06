# F18 — G7 Instruments & propriétés

## Portée

G7 qualifie les instruments et le panneau Propriétés sur la chaîne canonique :

`CircuitState -> TopologyEngine -> SolverEngine -> SimulationResult -> DeviceStateEngine -> UI/mesures`.

Aucune grandeur électrique de fonctionnement ne doit être fabriquée par l'UI.

## Implémentation

- Le `DeviceStateEngine` CC validé avant G7 reste intact.
- Des adaptateurs de domaine dédiés consomment les résultats AC1, AC3 et PV.
- AC1 expose les grandeurs d'une branche composant lorsqu'elles existent.
- AC3 ne fabrique pas une grandeur scalaire pour un composant multi-branche ; l'état peut être déterminé par les preuves moteur tandis que tension/courant/puissance restent absents si une agrégation ne serait pas physiquement justifiée.
- PV expose uniquement les grandeurs effectivement produites par `SolverPV`.
- `ElectroSimRuntimeSnapshot.componentOperatingState()` est le point de routage runtime vers `DeviceStateEngine`.
- Le panneau Propriétés distingue l'état déclaré de l'état calculé, humanise les paramètres électriques et expose les identifiants de preuves moteur.
- Les actions directes et le remplacement restent prioritaires dans la zone visible du panneau.
- Les mesures existantes restent routées par `MeasurementEngine`.

## Contrats et régressions

La qualification G7 exécute :

1. Flutter 3.38.10 / Dart 3.10.9.
2. `tools/f18_g7_contract.py`.
3. `dart format --set-exit-if-changed` sur les sources G7.
4. `flutter analyze` de l'application.
5. Tests G7 propriétés/instruments.
6. Régressions de mesures sans valeur fabriquée.
7. Régressions runtime AC1/AC3/PV.
8. Régression du shell F9.
9. `dart analyze` et `dart test` de `electrosim_measurements`.
10. Non-régression G6 des interactions/topbar.

## Preuve de développement déjà obtenue

Le run GitHub Actions `37441408227` est vert sur le SHA
`793c218c3a3b5f1336dc736526354384247a18d8`, y compris le marqueur
`F18_G7_INSTRUMENTS_PROPERTIES_GATE_PASS`.

Après cette preuve, les fichiers G7 ont été normalisés par la toolchain verrouillée.
Le workflow final est désormais strict sur le format et se relance aussi sur la branche
d'intégration.

## Critère de fermeture

Ce document ne déclare pas G7 PASS par lui-même.

G7 est PASS uniquement si le workflow **F18-G7 Instruments and properties** est
entièrement vert sur le SHA final exact de la branche G7, puis si la même
qualification est verte sur le SHA de fusion de la branche d'intégration.
