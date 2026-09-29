# F9 — Modèle d'état UI séparé de l'état électrique

## Principe

F9 manipule uniquement un état de présentation et d'interaction. Les grandeurs et états physiques restent produits par les couches F1→F7.

## État UI autorisé

- `selectedElementId` ;
- `hoveredElementId` ;
- `focusedElementId` ;
- `openPanel` ;
- `activeWorkspace` ;
- `paletteQuery` / catégorie visuelle ;
- `pendingWiringTerminalId` ;
- `compatibleTerminalIds` fournis par une politique extérieure au Canvas ;
- préférences d'affichage (grille, densité, panneaux) ;
- viewport graphique.

## État interdit dans l'UI comme source de vérité

- tension, courant, puissance ;
- `energized`, `running`, `faulted` ;
- validation électrique d'un montage ;
- réparation réussie ;
- état de protection déclenchée si non issu du moteur ;
- score TP calculé visuellement.

## Matrice visuelle

| Concept | Origine | Rendu F9 |
|---|---|---|
| selected | UI | contour/halo de sélection |
| hovered | UI | feedback discret desktop |
| focused | UI | focus clavier visible |
| wiring pending | interaction | borne de départ + ligne de prévisualisation |
| compatible target | politique applicative | borne mise en évidence |
| energized | SimulationResult / DeviceState | état visuel fonctionnel |
| faulted | résultat/diagnostic | symbole/état physique distinct de la sélection |
| warning | diagnostic | badge/alerte avec preuve |

La sélection ne doit jamais être confondue visuellement avec une panne.
