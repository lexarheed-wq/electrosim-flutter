# F9-R2 — Rapport candidat

## Objet

Correctif ciblé de la porte F9-R1 sur Flutter 3.38.10 / Dart 3.10.9.

## Défaut observé

`flutter analyze` du package `electrosim_ui_kit` s'arrêtait avec deux diagnostics `prefer_const_constructors` dans `test/design_system_test.dart` aux constructeurs `Scaffold` et `ElectroSimWorkspaceShell`.

## Correction

Le sous-arbre de test est placé dans un contexte `const` via `home: const Scaffold(...)`. Aucun fichier Dart de production F9, aucun package électrique et aucun fichier du Canvas F8 n'est modifié par ce correctif.

## Validation attendue sur le Mac de référence

```bash
./validate.sh
```

Marqueur attendu :

```text
F9_R2_GATE_PASS
```

Après ce marqueur, exécuter `./run_visual.sh` pour la revue physique du shell responsive.
