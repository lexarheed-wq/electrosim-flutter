# F9-R3 — Correctif de bootstrap des régressions Dart

## Constat sur Mac Monterey

F9-R2 atteignait les régressions du package `electrosim_domain`, puis `dart analyze` produisait des centaines de diagnostics (`package:test` non résolu, types du package non résolus, `expect`/`contains` indéfinis).

## Cause racine

Un candidat extrait proprement ne contient volontairement aucun `.dart_tool/package_config.json`. Le gate F9-R2 lançait directement `dart analyze` / `dart test` sur les sept packages Dart purs sans exécuter `dart pub get`. Les gates F1→F8 résolvaient explicitement les dépendances avant analyse et test.

## Correction R3

Pour chacun des packages suivants, le gate exécute désormais `dart pub get` avant `dart analyze` puis `dart test` :

- `electrosim_domain`
- `electrosim_topology`
- `electrosim_solver_dc`
- `electrosim_solver_ac`
- `electrosim_measurements`
- `electrosim_pv`
- `electrosim_energy`

Aucun fichier Dart de production n'est modifié entre F9-R2 et F9-R3.
