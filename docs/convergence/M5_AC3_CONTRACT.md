# M5 — Convergence AC3

M5 conserve le noyau triphasé V2 existant : L1/L2/L3/N explicites, séquence des phases, perte de phase, étoile/delta, courant de neutre et contrôle d'équilibrage.

La convergence porte uniquement sur les branches de composants :

- `resistor`, `lamp`, `inductor`, `capacitor`, `impedance` utilisent les branches M2 ;
- `switch` / `switch_spst` deviennent des branches idéales ouvertes/fermées ;
- `phase_sequence_probe` conserve son chemin spécialisé à trois bornes ;
- les protections et contacteurs tripolaires sont réservés à M6, car ils nécessitent plusieurs branches de puissance coordonnées.

Aucune bibliothèque de schémas ou pannes V1 n'est utilisée.
