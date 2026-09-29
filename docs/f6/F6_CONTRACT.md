# F6 — Contrat du solveur AC triphasé

## Entrées

- `CircuitState.mode == ElectricalMode.ac3`
- `TopologyGraph` de même `circuitId` et même `revision`
- fréquence `settings.frequencyHz` strictement positive
- L1, L2, L3 et N sont des conducteurs/nœuds explicites ; aucune multiplication d'un résultat monophasé par trois

## Modèles initiaux

- composants passifs bipolaires : `resistor`, `inductor`, `capacitor`, `impedance`
- sources : `ac_voltage_source`, `ac_current_source`, avec borne de phase explicitement taguée `l1`, `l2` ou `l3`
- `phase_sequence_probe` : capteur non chargeant à trois bornes qui observe l'ordre réel des conducteurs raccordés

## Résultats

- tensions complexes de tous les nœuds
- courant/tension/puissances de chaque branche
- tensions phase-neutre et ligne-ligne
- courants de ligne L1/L2/L3
- courant de neutre calculé comme retour vectoriel
- phases manquantes et état dégradé
- séquence de phase source et observations de séquence au niveau des sondes
- indicateurs de tension/courant équilibrés
- résidus matrice et KCL

## Topologies

Étoile et triangle sont représentés par le câblage réel des branches dans `CircuitState`. Le solveur ne contient aucun raccourci `phase × 3`.

Une étoile sans conducteur de neutre garde son point étoile flottant électrique : son potentiel est résolu par MNA à partir des trois branches de charge.

Une inversion de phases est testée en permutant physiquement les conducteurs raccordés à un `phase_sequence_probe`.
