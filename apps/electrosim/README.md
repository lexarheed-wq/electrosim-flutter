# ElectroSim app — F9-R7

F9-R7 utilise le Canvas F8 validé dans le shell responsive F9 et rend la palette de composants réellement interactive.

Implémenté :

- accueil à trois entrées ;
- navigation de session persistante ;
- shell compact / medium / expanded ;
- recherche de composants ;
- filtres par catégories ;
- Voir plus / Voir moins ;
- 12 composants pilotes CC ;
- glisser-déposer palette → platine ;
- ajout rapide par bouton `+` ;
- reconstruction immuable de `CircuitState` et incrément de révision ;
- position graphique ajoutée séparément dans `CircuitVisualLayout` ;
- compteur composants / sources ;
- Canvas F8 inchangé.

Non implémenté dans R6 : rendu graphique métier détaillé par famille, états visuels pilotés par `SimulationResult`, propriétés métier éditables complètes, écrans métier définitifs de Supervision/RD et goldens F9 finaux.
