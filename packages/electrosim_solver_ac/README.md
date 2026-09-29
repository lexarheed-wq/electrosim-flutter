# electrosim_solver_ac

Solveurs AC déterministes en Dart pur.

- `SolverAC1` : monophasé complexe, R/L/C, P/Q/S/cos φ.
- `SolverAC3` : triphasé explicite L1/L2/L3/N, étoile/triangle câblés réellement, déséquilibre, perte de phase et ordre des phases.

Aucune dépendance Flutter. Le package consomme `CircuitState` + `TopologyGraph` et ne modifie ni l'un ni l'autre.
