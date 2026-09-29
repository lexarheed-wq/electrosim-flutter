# F15-R4 — Runner scaffold hygiene

Correction ciblée de la qualification multi-plateforme.

- Le runner temporaire créé par `flutter create` peut ajouter `test/widget_test.dart`.
- Ce test de scaffold référence `MyApp` et ne fait pas partie d’ElectroSim.
- F15-R4 le supprime uniquement s’il contient la signature `MyApp`.
- Les vrais tests ElectroSim copiés depuis `apps/electrosim/test/` sont conservés.
- Le gate statique vérifie désormais explicitement cette règle.
