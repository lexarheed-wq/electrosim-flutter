# electrosim_scenarios

Ce package porte les **contrats** des exemples sains et des scénarios de panne autonomes.

## Règle de reconstruction

Les bibliothèques V1 ne sont pas une source de données. Aucun schéma, scénario, titre, identifiant, circuit, teacher-truth ou payload V1 ne doit être importé, converti ou copié dans la bibliothèque Flutter. Les bibliothèques finales seront reconstruites depuis zéro et validées contre le moteur Flutter.

Les fichiers `f10_examples.dart`, `f11_fault_scenarios.dart` et `f16_catalog.dart` présents dans la baseline G3R1 sont des **fixtures techniques historiques de V2**, utiles aux tests de contrats. Ils ne constituent pas la bibliothèque produit cible et devront être remplacés progressivement par le catalogue reconstruit.

Voir `REBUILD_POLICY.md`.
