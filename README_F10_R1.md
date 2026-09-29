# ElectroSim F10-R1 Candidate

Cette branche part exclusivement de la base F9 FIX10 validée (`F9_GATE_PASS`).

F10 introduit uniquement la bibliothèque d'exemples saine et neuve dans `packages/electrosim_scenarios`.
Aucune bibliothèque historique TypeScript n'est importée.

Porte F10 attendue :
1. `python3 tools/f10_static_contract_check.py`
2. `dart test packages/electrosim_scenarios/test`
3. `dart run packages/electrosim_scenarios/tool/validate_examples.dart`
4. vérification qu'aucune dépendance `FaultScenario` n'existe.

Le gate Dart/Flutter complet doit être exécuté avec la toolchain verrouillée Flutter 3.38.10 / Dart 3.10.9.
