# M9 — EIE fondé sur preuves

EIE reste un moteur de diagnostic interne, pas un coach élève.

## Sources de preuve

- TopologyEngine : nœuds flottants, composants/sources isolés, conflits de phases, contrats de composants incompatibles.
- Solveur CC : sources contradictoires, réseau singulier, résidu numérique, source en limitation de courant.
- Solveur AC1 : îlots, singularité, résidu, fréquence invalide.
- Solveur AC3 : mêmes preuves plus perte de phase.
- Device state : surcharge et surcharge sévère du récepteur selon le courant réellement calculé.

## Règles

- aucun conseil EIE sans `evidenceId` ;
- aucune cause inventée ;
- en état normal, le rapport reste silencieux (`insufficientEvidence` et aucun conseil) ;
- l'interface professeur peut afficher les preuves, mais les détails techniques peuvent rester masqués par défaut.
