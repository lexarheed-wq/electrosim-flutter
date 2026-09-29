# ElectroSim Flutter F12-R2

Correctif ciblé du gate F12-R1.

## Correction
- Le test TP câblage utilise le contrat réel `ExampleDefinition.circuit` au lieu du getter inexistant `circuitState`.
- Suppression de l'import `electrosim_domain` devenu inutile dans ce test.
- Aucun changement du noyau électrique, de F11, des scénarios de panne ou de l'algorithme TP.

## Contrat préservé
F12 reste fondé sur une machine à états explicite, diagnostic uniquement élève/RD, lecture seule après soumission, score généré, réparation recalculée par TopologyEngine + SolverDC, et une seule activité active.
