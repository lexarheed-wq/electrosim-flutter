# M0 — Matrice de convergence moteur V1 -> V2

| Domaine | Référence V1 | Destination V2 | Décision | Action | Phase |
|---|---|---|---|---|---|
| Domaine/CircuitState | V1 circuit model + coherence concepts | electrosim_domain | V2 à conserver | Comparer invariants puis enrichir sans legacy runtime | M1 |
| Topologie | B538/B9 topology | electrosim_topology | V2 à conserver | Porter seulement les cas physiques manquants | M2 |
| CC | C31/B11/DC historical solver | electrosim_solver_dc | V2 incomplet | Ajouter modèles/protections/limitation et cas de régression V1 | M3/M6 |
| AC1 | B11 + historical AC1 behavior | electrosim_solver_ac | V2 noyau présent | Étendre modèles, mesures et protections après tests | M4/M6/M7 |
| AC3 | B5 AC3 + C31.13 current limit | electrosim_solver_ac | V2 noyau présent | Étendre appareillages, limitation, déséquilibres validés | M5/M6 |
| PV | B5 PV + PVUX + METER01 | electrosim_pv + electrosim_energy | V2 noyau présent | Comparer modèles puis porter comportements prouvés | M8 |
| Mesures | B11 measurements + continuity/meter fixes | electrosim_measurements | V2 partiel (DC V/I/R) | Étendre modes et sécurité selon architecture cible | M7 |
| États appareils | receiver overload/contactors/thermal | electrosim_measurements + domain | V2 partiel | Recréer états/protections/appareillages en Dart | M6 |
| EIE | EIE01..EIE20 | electrosim_diagnostics | V2 minimal evidence-based | Porter capacités utiles sans heuristiques opaques | M9 |
| TP/session/supervision | B55 + TPFLOW + sync | electrosim_tp + app runtime | V2 base présente | Converger flux, clôture, notation, supervision | M10 |
| Canvas/routage | B10/UI V3 | electrosim_canvas | V2 prioritaire | Conserver G2A/G3R1 et améliorer qualité/interaction | M11/M12 |
| Visuels composants | V1 renderer/assets as visual oracle | Flutter renderers/UI kit | V1 meilleur rendu actuel | Recréer en Flutter/Figma, pas copier le runtime | M11/M12 |
| Schémas | V1 library | electrosim_scenarios | EXCLU DE MIGRATION | Reconstruction depuis zéro | REBUILD |
| Pannes | V1 library/FaultEngine | electrosim_scenarios | EXCLU DE MIGRATION | Reconstruction depuis zéro, scénarios autonomes | REBUILD |

Cette matrice décrit la convergence des **capacités**, pas une copie de code ou de données. Les lignes Schémas/Pannes sont explicitement hors migration.
