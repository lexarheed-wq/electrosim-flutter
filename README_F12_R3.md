# ElectroSim Flutter F12-R3

Correction de gate uniquement par rapport à F12-R2.

- restaure `dart pub get` dans `packages/electrosim_scenarios` avant `dart analyze`/`dart test` ;
- corrige les erreurs de résolution de package observées sur une extraction propre ;
- ajoute `tools/f12_gate_contract_check.py` pour empêcher la régression d'ordre `pub get -> analyze`.

Aucun contrat F11, scénario, solveur ou moteur TP n'est modifié.
