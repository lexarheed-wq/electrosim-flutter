# F9 — Plan goldens et acceptation

## Goldens obligatoires

Au minimum :

- compact 390×844 ;
- medium 820×1180 ;
- expanded 1440×900.

Pour chaque profil :

1. écran structurel avec Canvas ;
2. palette ouverte ;
3. composant sélectionné + panneau de propriétés ;
4. mode câblage ;
5. message d'erreur/diagnostic ;
6. état de chargement vide si applicable.

## Tests responsive

- aucun overflow ;
- aucune action principale hors écran ;
- transition de breakpoint sans perte de sélection/circuit ;
- panneaux fermables ;
- Canvas conserve des dimensions utilisables.

## Tests visuels composants

- même identité palette/Canvas ;
- bornes lisibles ;
- sélection non confondue avec défaut ;
- états électriques provenant du résultat moteur ;
- tailles cohérentes entre familles.

## Porte F9 préparée

La future porte devra au minimum vérifier :

- `flutter analyze` ;
- widget tests UI ;
- goldens approuvés sur trois profils ;
- audit overflow ;
- audit accessibilité ;
- régression F1→F8 ;
- absence de calcul électrique dans l'UI ;
- absence de mutation du `CircuitState` par la présentation.
