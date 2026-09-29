# F11-R1 — Nouvelle bibliothèque de pannes

Base obligatoire : F10-R3 validée par `F10_GATE_PASS`.

## Périmètre

- `FaultScenarioDefinition` autonome : le circuit remis à l’élève est déjà défectueux.
- `TeacherTruth` privé, absent du payload élève.
- Deux scénarios CC initiaux seulement : conducteur retour absent et composant en circuit ouvert.
- Réparations de référence modifiant réellement `CircuitState`, puis recalculées par `TopologyEngine` + `SolverDC`.
- Validation des symptômes électriques attendus, réparabilité et signature déterministe.
- Interdiction de `exampleId` et de toute injection cachée de panne.

## Porte F11

Le jalon n’est validé que lorsque `./validate.sh` affiche `F11_GATE_PASS`.
