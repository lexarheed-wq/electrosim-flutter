# F9-R1 — Contrat d'implémentation

## Prérequis

F8-R11 a obtenu `F8_GATE_PASS` sur macOS Monterey 12.7.6 avec Xcode 14.2 et Flutter 3.38.10.

## Portée de R1

F9-R1 ouvre réellement la phase UI avec deux lots contrôlés :

1. **F9.1 Design system** : tokens, thème clair, couleurs UI distinctes des codes électriques, surfaces et composants de statut.
2. **F9.2 Shell responsive initial** : profils compact `<600`, medium `600–1000`, expanded `>1000`, avec le Canvas F8 conservé comme surface de simulation.

La page d'accueil expose les trois entrées validées : Créer une nouvelle session, Centre de maintenance, Centre de conception.

## Invariants

- aucun calcul électrique dans `electrosim_ui_kit` ;
- aucun import des solveurs/topologie/mesures/énergie dans l'UI ;
- `CircuitState` reste fourni au Canvas et n'est pas muté par les breakpoints ;
- le code des packages F1→F8 est verrouillé par hash ;
- `apps/electrosim/lib/main.dart` est volontairement exclu du gel F8 car F9 remplace la composition visuelle de l'application.

## Hors portée R1

Palette métier réelle, drag/drop de création de composant, propriétés éditables, diagnostic élève RD, EIE, compatibilité de bornes F9, accessibilité complète et goldens F9 finaux.
