# F9 — Spécification du design system

## Objectif

Créer une interface moderne, professionnelle, pédagogique et cohérente sans déplacer la logique électrique dans la présentation.

## 1. Tokens

Les valeurs exactes seront implémentées dans un package UI dédié après ouverture F9. La hiérarchie suivante est préparée :

- **couleurs sémantiques** : primary, secondary, surface, surfaceElevated, outline, success, warning, danger, info ;
- **couleurs électriques** séparées des couleurs d'interface : DC+, DC−, L1, L2, L3, N, PE ;
- **espacements** : 4 / 8 / 12 / 16 / 24 / 32 ;
- **rayons** : compact, card, panel ;
- **élévations** : none, card, floating ;
- **typographie** : display, title, body, label, numeric/measurement ;
- **motion** : instant feedback, short transition, panel transition ; aucune animation ne peut simuler un état électrique absent du moteur.

## 2. Composants UI de base

- boutons primary / secondary / tonal / destructive ;
- icon button avec tooltip desktop et cible tactile suffisante ;
- cartes de session/activité ;
- panneau latéral ;
- bottom sheet compact ;
- toolbar simulateur ;
- chips d'état ;
- alertes et diagnostics ;
- champs numériques avec unité explicite ;
- menu contextuel composant/fil ;
- barre de statut de simulation.

## 3. États obligatoires

Chaque composant interactif doit définir : normal, hover (desktop), focus clavier, pressed, selected, disabled, error lorsque pertinent.

Les états électriques (`running`, `faulted`, etc.) restent distincts des états UI (`selected`, `hovered`).

## 4. Règles anti-régression

- aucune valeur électrique codée en dur dans un widget ;
- aucune animation comme preuve de fonctionnement ;
- aucune couleur de fil déterminée par un écran si la phase/polarité existe déjà dans le modèle ;
- aucun composant essentiel inaccessible sur compact ;
- les visuels palette et platine partagent une même identité de composant.
