# F9 — Proposition de tokens visuels

**Pré-implémentation uniquement.** Aucun token n'est encore codé en Dart.

| Catégorie | Proposition | Usage |
|---|---:|---|
| canvas background | `#F5F1E7` | surface de montage claire |
| app background | `#0B1220` | shell global |
| surface 1 | `#111C2E` | navigation/panneaux |
| surface 2 | `#17263D` | cartes/champs |
| border | `#2A3A52` | séparateurs |
| text primary | `#E8EEF7` | texte principal sombre |
| text muted | `#9FB0C7` | texte secondaire |
| brand/select | `#38BDF8` | sélection, focus, navigation active |
| positive | `#34D399` | confirmation, état sain de workflow |
| warning/terminal | `#F59E0B` | terminal/cible ou avertissement, selon contexte |
| destructive | `#FB7185` | erreur, action destructive |

## Échelle spatiale proposée

`4 / 8 / 12 / 16 / 24 / 32 / 48 px`.

## Rayons proposés

- contrôles : `10–12 px` ;
- cartes : `14–18 px` ;
- panneaux structurants : `18–24 px`.

## Cibles d'interaction

- souris : hit target minimal 32 px ;
- tactile : cible minimale 44 px ;
- terminal électrique : rendu visuel plus petit autorisé, hit-test agrandi en coordonnées écran ;
- focus clavier toujours visible.
