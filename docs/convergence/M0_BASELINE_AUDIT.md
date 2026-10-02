# M0 — Audit de baseline de convergence

## Entrées vérifiées

- V1 FIELDFIX01-R1 : SHA-256 `569e05908592e6dd615bd80b342f6c7a28249850951d353dac988c5d2e1187bd`.
- V2 source G3R1 : commit qualifié déclaré `f52da0acba9e93032433849756abfdea17dc442d`.
- Archive source G3R1 inspectée : `pubspec.yaml`, `lib/`, packages moteur, tests et workflows présents.

## Inventaire V1 constaté

- 239 fichiers JavaScript/TypeScript à la racine de la référence extraite.
- 354 fichiers de tests `test_*` à la racine.
- Modules historiques majeurs repérés : topologie, mesures, diagnostics, AC3, PV, énergie, contacteurs, surcharge récepteur, EIE, TP/supervision, canvas.

## Inventaire V2 constaté

Packages structurants présents : `electrosim_domain`, `electrosim_topology`, `electrosim_solver_dc`, `electrosim_solver_ac`, `electrosim_pv`, `electrosim_measurements`, `electrosim_energy`, `electrosim_diagnostics`, `electrosim_scenarios`, `electrosim_tp`, `electrosim_storage`, `electrosim_canvas`, `electrosim_ui_kit`.

Limites visibles à traiter dans les phases suivantes : le solveur CC supporte actuellement surtout resistor/lamp/switch, AC1 resistor/inductor/capacitor/impedance, les mesures sont centrées DC V/I/R, et le diagnostic V2 est volontairement minimal. Cela confirme qu'une convergence fonctionnelle progressive est nécessaire.

## Décision M0

La base de travail est V2 Flutter. V1 reste un oracle fonctionnel/visuel. Les bibliothèques Schémas/Pannes V1 sont totalement exclues de la migration et seront reconstruites indépendamment.
