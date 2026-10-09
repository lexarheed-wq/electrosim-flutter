# Post-V2 — P2/R1 : fondation géométrique de l'armoire

## Référence

Cahier des charges post-V2, p. 6, lot P2.

## Objectif du premier incrément

Introduire un modèle d'implantation indépendant du schéma électrique :

- Rails DIN avec position et dimensions modifiables ;
- goulottes réalistes et zones de borniers ;
- placement libre ou assistance à l'alignement DIN ;
- refus/alerte de collision sans altérer les composants ou les fils ;
- rendu géométrique en coordonnées monde, compatible pan/zoom ;
- sauvegarde versionnée : nouveau schéma 2, ancien schéma 1 préservé ;
- aucun changement de courant, de bornes, de moteur ou de solveur.

## Livré dans R1

`CabinetLayout` immuable, `CabinetFixture`, et
`CabinetPlacementPlanner` portent uniquement de la géométrie.
`CircuitVisualLayout` conserve les fixtures lors des opérations.
`CircuitScenePainter` peint les fixtures sur sa couche arrière.
`ElectroSimLayoutPersistence` sérialise et valide les données d'armoire.

## Reste à réaliser pour la fermeture P2

- Contrôles UI pour créer/sélectionner/déplacer/redimensionner les rails,
  goulottes et zones physiques depuis le poste enseignant ;
- placement assisté DIN connecté à l'interaction de déplacement des composants ;
- implantation des vrais borniers et routage de câbles à l'intérieur des goulottes ;
- validation anti-collision dans le flux utilisateur ;
- gestion de plusieurs appareils, tailles physiques en unités industrielles ;
- sauvegarde/Undo/Redo de la géométrie depuis les commandes effectives ;
- performances avec grande armoire, preuve visuelle de référence,
  tests d'interaction et validation physique sur Mac.

Les fixtures ne deviennent jamais des nœuds électriques.
Les rails décoratifs historiques restent présents pour les projets sans
aménagement explicite. Une fixture DIN explicite masque les supports
décoratifs du même emplacement, sans déplacer les composants.

## Portée et gate

Ceci est P2 **R1**, non la clôture de P2. La qualification de la branche
doit inclure `flutter analyze`, la suite Canvas et la suite complète
de l'application ainsi que les tests de persistance P2.
