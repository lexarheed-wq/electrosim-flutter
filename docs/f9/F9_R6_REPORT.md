# F9-R7 — Palette réelle et glisser-déposer

## Périmètre implémenté

F9-R7 transforme la palette de démonstration en un premier outil de conception utilisable sans toucher au noyau électrique F1→F8.

### Catalogue pilote

12 éléments CC : source 24 V, interrupteur NO, lampe, résistance, disjoncteur, bouton-poussoir NO, buzzer, fusible, diode, ventilateur CC, moteur CC et bobine relais.

### Recherche et navigation

- champ de recherche ;
- catégories Sources / Commande / Récepteurs / Passifs / Protection ;
- affichage initial limité à six entrées ;
- bouton Voir plus / Voir moins ;
- compteur de résultats.

### Dépôt sur la platine

- `LongPressDraggable<F9PaletteDefinition>` dans la palette ;
- `DragTarget<F9PaletteDefinition>` autour du Canvas ;
- conversion position écran → monde par `ViewportController` ;
- `CircuitState` reconstruit de manière immuable avec révision +1 ;
- `CircuitVisualLayout` mis à jour séparément ;
- aucune grandeur électrique calculée dans l'UI ;
- bouton + de secours qui ajoute au centre de la zone visible.

### Séparation des responsabilités

La palette décrit l'intention utilisateur. Elle n'appelle aucun solveur. La couche application crée une instance de domaine valide et une position graphique. Le Canvas continue seulement de consommer `CircuitState` et `CircuitVisualLayout`.

## Tests ajoutés

- recherche et bouton Voir plus déterministes ;
- ajout rapide créant réellement une nouvelle instance de domaine ;
- glisser-déposer palette → Canvas ;
- compteur de circuit après ajout ;
- non-régression shell/navigation et Canvas F8.

## Porte attendue

```text
F9_R7_GATE_PASS
```

La validation Flutter complète doit être exécutée sur le Mac Monterey de référence.
