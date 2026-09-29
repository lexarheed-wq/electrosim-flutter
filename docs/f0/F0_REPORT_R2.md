# Rapport F0 R2 — continuation contrôlée

Date: 27 septembre 2026  
Version: `0.0.0-f0-r2-candidate`  
Décision: **NO-GO vers F1 tant que la porte Flutter n'a pas été exécutée avec succès**

## Travail ajouté en R2

1. Pin CI sur Flutter `3.47.5` stable.
2. Workflow GitHub Actions `F0 quality gate` exécutant la porte officielle F0.
3. Audit runtime du toolchain (`toolchain_probe.py`).
4. Journal machine-lisible de la porte (`audit/f0_gate_runtime.json`).
5. Bootstrap local isolé sous `.toolchain/`, sans installation système.
6. Tests Python du tooling F0 et garde structurelle cumulative.
7. Maintien de l'interdiction de démarrer F1 sans preuve `flutter analyze` + `flutter test`.

## Preuves exécutées dans le runtime actuel

- `python3 tools/test_f0_tooling.py`: PASS.
- `python3 tools/f0_guard.py`: PASS.
- Vérification de syntaxe Python (`py_compile`): PASS.
- Le runtime actuel ne contient toujours pas Flutter/Dart; la porte Flutter reste donc BLOCKED ici.

## Condition exacte de passage F0

La phase F0 peut être marquée GO uniquement lorsqu'un journal d'exécution réel montre simultanément :

- `dart format --output=none --set-exit-if-changed .` vert;
- `flutter pub get` vert;
- `flutter analyze` vert;
- `flutter test` vert;
- `f0_guard.py` vert;
- référence historique inchangée et hash conforme.

Aucune implémentation F1 n'est incluse dans ce candidat.
