# F9-R11 — placement sûr de l’ajout rapide

## Constat de la revue physique R10

La palette R10 fonctionne : recherche, catégories, bouton Voir plus/Voir moins, ajout rapide, drag palette → platine, sélection et identifiants `lamp-2`, `lamp-3` sont observables. La barre d’état large ne présente pas d’overflow sur la vidéo.

Un défaut visuel reste bloquant : un ajout par `+` peut apparaître au-dessus d’un fil existant ou d’un autre élément. Le nouvel élément reste électriquement isolé dans `CircuitState`, mais le rendu peut laisser croire à une connexion réelle. Cette ambiguïté est contraire à la séparation stricte état électrique / état graphique.

## Correction

`F9AutoPlacement` choisit désormais une position monde libre dans le viewport courant. Il rejette les candidats qui chevauchent un rectangle d’élément existant ou une polyligne de câblage, avec marge de sécurité. Si aucune zone libre n’existe dans le viewport, l’ajout automatique est refusé plutôt que de créer un chevauchement ambigu. Le drag manuel n’est pas modifié.

## Preuves automatisées ajoutées

- évitement d’un rectangle occupé ;
- évitement d’un segment de fil traversant la position préférée ;
- deux ajouts successifs réservent des positions distinctes ;
- refus déterministe lorsque le viewport est saturé ;
- garde statique exigeant le moteur et ses tests ;
- F1→F8 core freeze toujours obligatoire.

## Validation physique encore requise

Après `F9_R11_GATE_PASS`, ajouter successivement une source, deux lampes et une résistance avec `+`. Aucun nouvel élément ne doit se superposer à un fil ou à un appareil. Vérifier ensuite un drag manuel vers une zone libre, puis réduire la largeur de la fenêtre pour confirmer le mode compact.
