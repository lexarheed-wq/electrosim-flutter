# ElectroSim F13-R1 — EIE fondé sur preuves

Base: F12-R3 validée par `F12_GATE_PASS`.

## Contrat
- Runtime EIE indépendant des scénarios pédagogiques privés.
- Chaque conseil cite au moins un `evidenceId` réellement présent.
- Les preuves proviennent uniquement de `TopologyFinding`, diagnostics solveur ou résultats de branche.
- Les cibles de localisation/surlignage sont explicites.
- Si les preuves sont insuffisantes, aucun conseil diagnostique n'est inventé.
- Révision topologie/résultat strictement cohérente.
- Aucun `teacherTruth`, `FaultScenario`, `exampleId` ou dépendance scénarios dans le runtime diagnostics.

Gate attendu: `F13_GATE_PASS`.
