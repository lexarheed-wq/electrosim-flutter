# F9 — Plan d'implémentation préparé (non exécuté)

## Condition de départ

Ne pas exécuter ce plan avant `F8_GATE_PASS`.

## Lot F9.1 — Tokens et thème

Créer le package UI kit, tokens sémantiques, thème clair initial, typographie, espacements et états. Tests : analyse + snapshot des tokens + contraste.

## Lot F9.2 — Shell responsive

Implémenter les trois profils compact/medium/expanded sans fonctionnalités métier supplémentaires. Tests : breakpoints, absence d'overflow, conservation du Canvas.

## Lot F9.3 — Palette

Créer palette responsive et cartes composants à identité cohérente avec le Canvas. Le dépôt d'un composant restera une commande métier, pas une mutation graphique directe.

## Lot F9.4 — Panneau contextuel

Propriétés, sélection et actions contextuelles. Les valeurs électriques restent en lecture depuis les résultats ; les modifications passent par les commandes applicatives prévues.

## Lot F9.5 — Feedback de câblage

Brancher au Canvas une politique externe de compatibilité des bornes afin de surligner les cibles compatibles/incompatibles sans déplacer les règles électriques dans Flutter.

## Lot F9.6 — Accessibilité

Semantics, focus clavier, raccourcis, alternatives au double-clic, tailles tactiles et tests de texte augmenté.

## Lot F9.7 — Goldens et audit

Produire les goldens des trois profils, revue humaine, audit overflow/accessibilité et rapport F9. Aucun GO tant que les contrôles ne sont pas verts.
