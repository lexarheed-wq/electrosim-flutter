# M3A — Contrat de convergence du solveur CC

Statut cible : qualification CI Flutter 3.38.10 / Dart 3.10.9.

## Portée

M3A enrichit le solveur CC sans modifier AC1, AC3, PV ni les bibliothèques Schémas/Pannes.

### Invariants

1. Les composants DC utilisent les branches structurelles produites par M2 ; le solveur ne déduit plus leur branche depuis `terminals[0]` / `terminals[1]`.
2. `resistor` et `lamp` disposent d'un contrat structurel canonique à deux bornes.
3. `breaker_dc` et `fuse_dc` sont des branches de protection idéales ouvertes/fermées. Le déclenchement thermique ou magnétique automatique reste hors M3A et sera traité en M6.
4. La limite de courant d'une source de tension DC utilise uniquement la clé canonique `currentLimitA`.
5. Une source non limitée reste un générateur de tension idéal.
6. Une source dépassant `currentLimitA` passe dans un régime de courant borné et le réseau est résolu à nouveau ; le courant n'est jamais simplement tronqué dans le résultat.
7. Le nombre d'itérations du régime limité est borné par `DcSolverOptions.maxCurrentLimitIterations`.
8. `receiverNominalCurrentA`, `protectionRatedCurrentA` et `currentLimitA` restent trois grandeurs distinctes.
9. Aucun alias V1 tel que `Imax` n'est accepté.

## Non-objectifs

- courbes temps/courant des protections ;
- déclenchement thermique ;
- coordination sélective ;
- AC1/AC3 ;
- reconstruction des bibliothèques Schémas/Pannes.
