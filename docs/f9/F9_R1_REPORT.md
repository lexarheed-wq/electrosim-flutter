# F9-R1 — Rapport candidat

**Statut serveur :** contrôles statiques réalisables sans SDK Flutter terminés. Validation Flutter réelle requise sur le Mac Monterey de référence.

## Implémentation

- package `electrosim_ui_kit` créé ;
- design tokens sémantiques ;
- thème Material 3 clair ;
- breakpoints conformes au contrat F9 ;
- shell compact/medium/expanded ;
- accueil à trois entrées ;
- navigation session minimale ;
- Canvas F8 intégré sans modification de `electrosim_canvas` ;
- tests widget préparés pour home, breakpoints, panneaux et absence d'overflow compact ;
- gate `F9_R1_GATE_PASS` dédié.

## Validation attendue sur Mac

`./validate.sh` doit produire `F9_R1_GATE_PASS`. Ensuite `./run_visual.sh` permet la revue physique responsive et des interactions F8 dans le nouveau shell.
