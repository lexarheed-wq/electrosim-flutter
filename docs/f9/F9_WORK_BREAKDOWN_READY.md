# F9 — Découpage prêt à exécuter après F8_GATE_PASS

Ce WBS est prêt mais **non exécuté**.

## F9.1 — UI kit et tokens

Sorties : thème, tokens sémantiques, composants de base, tests de contraste/états. Aucun écran métier.

## F9.2 — Shell et navigation

Sorties : accueil à trois entrées, shell session, dashboard professeur. Tests navigation et absence de régression de session.

## F9.3 — Responsive

Sorties : compact/medium/expanded avec Canvas conservé. Tests de breakpoint et overflow.

## F9.4 — Palette et identité composant

Sorties : catalogue visuel de familles, cartes de palette, cohérence avec rendu Canvas. **Pas d'import des 217 items legacy** : l'inventaire sert seulement de taxonomie de référence.

## F9.5 — Panneaux contextuels

Sorties : propriétés, mesures, EIE shell, diagnostic élève RD uniquement. Tests rôle/contexte.

## F9.6 — Feedback de câblage

Sorties : compatibilité fournie au Canvas, surlignage cible, annulation/erreurs accessibles.

## F9.7 — Accessibilité

Sorties : focus, Semantics, raccourcis, alternative aux gestes doubles, texte augmenté.

## F9.8 — Goldens + audit

Sorties : goldens 390×844 / 820×1180 / 1440×900, audit overflow, rapport accessibilité, architecture guard, rapport F9.

## Porte de départ

Ne créer aucun fichier de production F9 avant `F8_GATE_PASS` + revue visuelle F8.
