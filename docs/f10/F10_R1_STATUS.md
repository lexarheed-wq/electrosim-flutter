# F10-R1 — État de validation

## Base
F9 FIX10 validée physiquement et automatiquement sur macOS Ventura 13.7 avec le marqueur `F9_GATE_PASS`.

## Implémenté
- `ExampleRepository` neuf.
- `ExampleValidator` neuf.
- 3 exemples CC sains seulement.
- Validation par `TopologyEngine` + `SolverDC`.
- `ExampleValidationStamp` déterministe.
- Garde de gel de la base F9.
- Gate F10 dédié (`./validate.sh`).
- Aucun `FaultScenario`, aucun `teacherTruth`, aucune injection de panne.

## Contrôles exécutés dans l'environnement de construction
- F9 freeze check : PASS.
- F10 static contract : 8/8 PASS.
- F10 manifest : PASS.
- F10 manifest verify : PASS, 0 erreur.
- Syntaxe shell du gate : PASS.

## Contrôle restant avant validation F10
Le gate Dart/Flutter complet doit être exécuté avec Flutter 3.38.10 / Dart 3.10.9. Le script `./validate.sh` recherche automatiquement une toolchain locale verrouillée dans ce candidat ou dans un candidat ElectroSim voisin.

Ne pas annoncer `F10_GATE_PASS` tant que ce marqueur n'a pas été produit par le gate réel.
