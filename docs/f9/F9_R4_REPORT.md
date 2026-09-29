# F9-R4 — Rapport de correction après revue visuelle R3

## Constat R3

La vidéo de validation macOS confirme que le shell responsive, le Canvas F8, les panneaux Palette/Propriétés, le recentrage et le changement d'espace s'exécutent sans crash. Deux écarts UX sont toutefois visibles avant validation visuelle de F9 :

1. la navigation de session ne matérialisait pas clairement les trois destinations persistantes prévues par le contrat : **Accueil / Tableau de bord / Gérer la session** ;
2. le menu de branche placé directement dans le workspace reproposait Câblage / Recherche de dérangement / Supervision à l'intérieur du simulateur, alors que le contrat prévoit ce choix au niveau du tableau de bord.

Un défaut de calcul de largeur des cartes de l'accueil medium a aussi été identifié : la largeur était calculée depuis le viewport extérieur puis appliquée à une zone déjà paddée, et la marge implicite de `Card` empêchait les deux premières cartes de partager correctement la même ligne.

## Correction R4

- largeur des cartes calculée dans le `LayoutBuilder` de la zone utile ;
- `Card.margin = EdgeInsets.zero` ;
- navigation session explicite et persistante ;
- dialogue Tableau de bord avec les trois branches métier ;
- suppression du sélecteur de branche direct dans le workspace de session ;
- maintenance initialisée en Recherche de dérangement ;
- conception initialisée en Câblage ;
- nouveaux tests widget pour la navigation et le layout medium.

## Invariants

- aucun changement de `CircuitState` lié au responsive ;
- aucun calcul électrique ajouté à l'UI ;
- package Canvas F8 inchangé ;
- packages F1→F8 toujours protégés par le gel de hash.

## Porte R4

La phase n'est pas déclarée visuellement validée tant que le Mac de référence n'a pas obtenu `F9_R4_GATE_PASS` puis confirmé l'affichage réel avec `./run_visual.sh`.
