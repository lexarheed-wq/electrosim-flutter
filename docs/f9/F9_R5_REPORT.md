# F9-R5 — Correction du parcours Centre de maintenance

## Échec observé en R4

Le gate R4 atteint les tests widget puis échoue sur :

`maintenance enters troubleshooting without re-proposing session dashboard`

L'assertion exige qu'après ouverture du **Centre de maintenance**, le libellé **Recherche de dérangement** ne soit présenté qu'une seule fois. En R4, le workspace l'affichait à la fois comme sous-titre de la barre supérieure et comme `ElectroSimStatusChip`. Le parcours ne reproposait pas le tableau de bord, mais répétait visuellement la branche active.

## Correction R5

- la branche active reste affichée une seule fois dans le sous-titre du workspace ;
- le chip de droite des entrées directes affiche maintenant **Accès direct** au lieu de répéter la branche ;
- le chip reçoit la clé `direct-entry-status` afin que le contrat widget soit explicite ;
- le test maintenance vérifie désormais à la fois l'unicité de `Recherche de dérangement`, la présence de `Accès direct`, l'absence du bouton Tableau de bord et la présence du Canvas F8.

## Invariants

- aucun changement du noyau électrique ;
- aucun changement du package `electrosim_canvas` F8 ;
- aucun calcul électrique ajouté à l'UI ;
- le gel F1→F8 reste obligatoire ;
- la navigation de session R4 reste inchangée.

## Porte R5

Sur le Mac de référence :

```bash
cd ~/Downloads/ElectroSim-Flutter-F9-R5-MONTEREY-CANDIDATE
chmod +x validate.sh run_visual.sh tools/*.sh
./validate.sh
```

Résultat attendu :

```text
F9_R5_GATE_PASS
```
