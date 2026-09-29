# F9 — Accessibilité et cohérence souris/tactile/clavier

## Exigences

- focus visible sur tout contrôle clavier ;
- libellés Semantics sur actions principales ;
- composants du Canvas exposés comme éléments navigables lorsque cela ne dégrade pas les performances ;
- action de sélection et menu contextuel accessibles sans double-clic obligatoire ;
- contraste suffisant pour texte, sélection et alertes ;
- information de phase/état non codée uniquement par couleur ;
- taille de texte adaptable sans overflow critique.

## Mapping d'entrée cible

| Intention | Souris | Tactile | Clavier |
|---|---|---|---|
| Sélection | clic | tap | focus + Enter/Espace |
| Déplacement | appui/drag contrôlé | appui long + glisser | commande dédiée après sélection, si activée |
| Connexion | clic borne | tap borne | action « commencer/terminer connexion » |
| Contexte | double-clic ou menu | double-tap ou menu | touche menu / raccourci |
| Pan | drag fond | drag fond | flèches/modificateur si utile |
| Zoom | molette/pinch trackpad | pinch | +/- |
| Annuler câblage | fond/Escape | fond/bouton annuler | Escape |

## Tests préparés

- navigation clavier des barres/panneaux ;
- focus visible ;
- Semantics des boutons ;
- taille de texte augmentée ;
- contraste ;
- absence d'action indispensable uniquement au hover ;
- Escape annule le mode de câblage lorsqu'il existe.
