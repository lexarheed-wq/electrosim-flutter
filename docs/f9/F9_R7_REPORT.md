# F9-R7 — Correction analyseur Flutter

## Objet

F9-R7 corrige uniquement le blocage remonté sur macOS Monterey lors de `flutter analyze` dans l'application F9-R6.

## Défaut observé

L'analyseur signalait `unnecessary_brace_in_string_interps` dans `apps/electrosim/lib/main.dart` sur l'interpolation de `elementId`.

## Correction

- `${elementId}` devient `$elementId` dans le message d'état après ajout d'un composant.
- Aucun comportement fonctionnel n'est modifié.
- Le noyau électrique et le Canvas F8 restent gelés.
- Les fonctions F9-R6 (palette, recherche, catégories, Voir plus/Voir moins, glisser-déposer, ajout rapide) restent inchangées.

## Gate attendu

`F9_R7_GATE_PASS`
