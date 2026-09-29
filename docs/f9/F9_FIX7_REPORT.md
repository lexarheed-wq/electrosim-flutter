# F9 FIX7 — Cohérence du statut circuit

## Défaut observé
La barre d'état affichait `2 composants · 1 source` alors que trois éléments électriques étaient visibles (source, interrupteur, lampe). La valeur était techniquement issue de deux collections distinctes (`components` et `sources`) mais le libellé pouvait être interprété comme un total visuel.

## Correction
La barre d'état affiche désormais le **nombre total d'éléments électriques** (`components + sources`) puis détaille le nombre de sources. Exemple initial : `3 éléments · 1 source · DC · Révision 1`.

Le format compact devient `3 élém. · 1 src.`.

## Non-régression
Les attentes widget F9 ont été adaptées au contrat produit clarifié et un contrôle statique dédié `f9_status_bar_static_check.py` est intégré au gate final.

Aucun fichier du noyau F1→F8 gelé n'est modifié.
