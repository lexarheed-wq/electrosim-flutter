# F10-R1 — Bibliothèque d’exemples neuve

Base: F9 FIX10 ayant obtenu `F9_GATE_PASS` sur macOS Ventura 13.7.

## Portée volontairement petite
- EX-DC-001 : source 24 V + résistance 12 Ω.
- EX-DC-002 : 30 V + résistances 10 Ω et 20 Ω en série.
- EX-DC-003 : 24 V + interrupteur fermé + charge résistive 24 Ω.

## Contrats
- Exemples = circuits sains, câblés, autonomes et fonctionnels.
- `CircuitState` reste l’unique état électrique.
- Validation électrique par `TopologyEngine` + `SolverDC`.
- Aucun `FaultScenario`, aucune injection de panne, aucun `teacherTruth`.
- Chaque exemple publié reçoit un `ExampleValidationStamp` déterministe.
- La bibliothèque commence petite : qualité avant quantité.
