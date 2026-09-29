# F9 — Audit visuel de la référence historique

Ce document utilise l'ancienne application **uniquement comme référence ergonomique/visuelle**. Il ne prescrit aucune reprise de son architecture.

## Références archivées

- `reference_screens/legacy_home_reference.png` — accueil de référence ;
- `reference_screens/legacy_workspace_desktop.png` — workspace desktop historique ;
- `reference_screens/legacy_workspace_mobile_student.png` — workspace élève mobile historique.

## 1. Accueil — éléments à conserver conceptuellement

Points forts observables :

- trois entrées principales clairement différenciées ;
- identité ElectroSim immédiatement reconnaissable ;
- hiérarchie typographique forte ;
- distinction visuelle maintenance / conception / session.

À ne pas transposer tel quel dans le workspace :

- effets néon et illustration décorative trop denses pour une surface de travail prolongée ;
- couleurs de marque susceptibles d'entrer en conflit avec les couleurs électriques si elles sont utilisées sans sémantique.

Décision préparée : **accueil expressif, workspace technique et plus sobre**.

## 2. Workspace desktop — dette observable

La capture historique montre :

- toolbar supérieure très chargée ;
- palette gauche toujours ouverte ;
- panneau propriétés droit toujours ouvert ;
- plusieurs niveaux d'actions et de modes concurrents dans la même ligne ;
- informations d'aide persistantes qui consomment de l'espace ;
- Canvas central correctement priorisé sur grand écran, mais avec une densité de chrome élevée.

Décisions F9 préparées :

- réduire la top bar aux actions globales et au contexte actif ;
- déplacer les actions contextuelles près du contexte ou dans un panneau ;
- permettre de replier palette/propriétés ;
- réserver les couleurs électriques aux phases/polarités et états physiques ;
- garder les outils de mesure et de simulation visibles sans multiplier les boutons permanents.

## 3. Workspace mobile — problème critique observable

La capture élève mobile historique montre un Canvas réduit à une bande étroite à gauche tandis qu'un grand panneau propriétés occupe la majorité de l'écran.

C'est précisément le comportement à **interdire** dans F9 :

- le Canvas doit occuper la surface utile principale ;
- propriétés/palette/diagnostic deviennent des sheets superposées ;
- la barre d'actions basse reste compacte ;
- aucun texte de statut ne doit provoquer de scroll horizontal.

## 4. Conséquences sur les goldens F9

Les goldens doivent démontrer explicitement :

- compact : Canvas dominant, aucun panneau latéral permanent ;
- medium : un seul panneau secondaire simultané ;
- expanded : palette + Canvas + panneau contextuel possibles sans étouffer le Canvas ;
- les mêmes composants gardent la même identité visuelle dans palette et platine.
