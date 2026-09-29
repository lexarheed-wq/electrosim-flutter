# Rapport F6-R1 — Candidat AC triphasé

## Objectif

Introduire le solveur AC3 sans modifier les contrats validés F1–F5.

## Ajouts

- `Ac3SolverOptions`
- `Ac3SolverDiagnostic`
- `Ac3SolveResult`, résultats de branche et observation d'ordre des phases
- `SolverAC3` par MNA complexe sur un réseau complet L1/L2/L3/N
- cas étoile 4 fils, étoile 3 fils, triangle, charge déséquilibrée, perte de phase, inversion de deux conducteurs
- benchmark AC3
- garde d'architecture et contrôle statique F6
- porte cumulative F6

## Preuves préparées

Le corpus Dart F6 vérifie notamment :

- AC3-001 : charge étoile équilibrée, trois courants équilibrés ;
- AC3-002 : perte L2, état dégradé et courant L2 nul dans la branche concernée ;
- AC3-003 : permutation physique L2/L3 vue comme séquence négative par la sonde ;
- triangle équilibré avec courants de branche et de ligne distincts ;
- étoile déséquilibrée avec et sans conducteur de neutre ;
- déterminisme, erreurs structurées, singularités et résidus numériques.

## Statut

CANDIDAT. Le jalon devient F6 validé uniquement après `F6_GATE_PASS` sur le SDK Flutter/Dart verrouillé Monterey.
