# M4 — Convergence AC1

## Portée

- Le solveur AC1 consomme les branches structurelles de M2 pour les composants.
- Les modèles passifs canoniques sont `resistor`, `lamp`, `inductor`, `capacitor`, `impedance`.
- `switch` / `switch_spst` utilisent `controlState.closed`.
- `breaker_ac1` / `fuse_ac1` utilisent le calibre canonique `protectionRatedCurrentA` et les états `closed/tripped`.
- Une protection fermée est une branche idéale ; M4 ne déclenche pas automatiquement la protection.
- Les sources restent des éléments source à deux bornes explicites. La coordination de limitation de courant sera traitée avec les appareillages/protections.

## Invariants

1. Aucun calcul AC1 ne déduit la branche d'un composant via `terminals[0]/[1]`.
2. Courant nominal récepteur, calibre de protection et limite source restent distincts.
3. Aucune donnée de bibliothèque Schémas/Pannes V1 n'est utilisée.
