# Vérification du dernier lot — 12 octobre 2026

## Résultats exécutés

- 83 tests ciblés passent : contrats, résolution, migration des bornes, mise à la terre, routages étoile/triangle, compteurs et fonctionnement historique.
- 15 tests supplémentaires passent : restauration des sources triphasées et tailles personnalisées, intégration C15.
- Le test de restauration de la taille par défaut du téléviseur passe séparément.
- La première campagne de captures Flutter passe pour les 14 composants, avant le nouveau contrôle explicite de rotation. Elle produit les 42 PNG présentés ici.
- Le contrôle explicite ajouté ensuite révèle une rotation nulle du ventilateur triphasé. Cause : la lecture attendait une observation réservée aux sondes d'ordre des phases.
- La correction lit les tensions de chaque enroulement dans l'instantané résolu. Huit vérifications Dart directes passent (étoile, triangle, permutation de phases, pause, fréquence, révolution complète). Script : `apps/electrosim/tool/verify_three_phase_rotor.dart`.
- Analyse statique des 14 fichiers d'intégration : aucune anomalie. Analyse finale du rotor et des deux outils : aucune anomalie.
- Suites Dart exécutées hors ligne : domaine 41/41, PV 43/43.
- 47 images installées correspondent aux empreintes des rendus Blender ; les 14 contrôles structurels Blender ont passé.

**Vérification finalisée le 12/10/2026 :** contrôle Flutter de rotation et capture exécuté après autorisation du port local : 18 tests passent. Les captures du dossier ont été actualisées. Voir aussi [l’audit des 82 entrées](../catalogue-audit-20261012/README.md).

## Suite globale et comparaison historique

La suite complète locale a donné 715 succès, 18 échecs et 2 tests ignorés, avant adaptation des deux attentes devenues obsolètes (ancienne image de charge PV et ancienne taille par défaut TV).

Les huit fichiers concernés ont été réexécutés sur le commit publié `c9a07e4f` dans un checkout séparé : 49 succès et **16 échecs identiques**. Les deux échecs supplémentaires du lot ont été corrigés dans les assertions et passent maintenant. La reprise sur la G5 récente a ensuite corrigé le défaut PV et les écarts de palette/fixtures ; la suite consolidée passe maintenant **744 tests, 2 ignorés, 0 échec**. Les références F9 ont été inspectées avant actualisation. Voir le rapport consolidé pour les détails et les réserves Mac.

Liste historique des 16 échecs traités lors de la reprise :

- `f18_g3r1_point05_palette_contract_test.dart: F18 palette exposes exactly five quick components`
- `f18_g3r1_point05_palette_contract_test.dart: quick add preserves visual model and variant on the board component`
- `f9_goldens_test.dart: compact 390x844 reference set`
- `f9_goldens_test.dart: medium 820x1180 reference set`
- `f9_goldens_test.dart: expanded 1440x900 reference set`
- `f9_goldens_test.dart: student troubleshooting diagnostic reference`
- `f18_g3r1_point10_integrated_visible_contract_test.dart: design workspace starts on a truly blank board`
- `sim_r1_instrument_palette_discoverability_test.dart: physical instruments appear under Voir tous in dc`
- `sim_r1_instrument_palette_discoverability_test.dart: physical instruments appear under Voir tous in ac1`
- `sim_r1_instrument_palette_discoverability_test.dart: physical instruments appear under Voir tous in ac3`
- `sim_r1_instrument_palette_discoverability_test.dart: physical instruments appear under Voir tous in pv`
- `f9_shell_test.dart: palette quick add creates a real CircuitState element and selects it`
- `f9_shell_test.dart: palette allocation never collides with an existing element id`
- `f9_shell_test.dart: drag from palette drops a component on the canvas`
- `g5_audit_observed_pv_instrument_regression_test.dart: METER: real series burden reads 48V battery current in pv`
- `audit_canvas_routing_performance_test.dart: insertion and pointer-up never invoke global routing synchronously`

Le contrôle de routage historique échoue sur une recherche textuelle de méthode renommée, pas sur une mesure effective de latence. Les différences de captures ont été examinées avant adaptation des seules références F9 ; aucune tolérance arbitraire ou suppression de test n'a été introduite.

## Compilation

Les tentatives de compilation ne constituent pas un succès : Android SDK absent, clang++ absent pour Linux, cible web non configurée. Aucune compilation distribuable de cette étape n'est revendiquée. Ces obstacles d'environnement sont distincts d'une erreur du code.

## Commandes de reprise

Depuis `apps/electrosim`, avec Flutter 3.38.10 :

```sh
flutter test --no-pub tool/capture_g5_lot_16_26_test.dart test/industrial_audio_motion_test.dart
dart --packages=.dart_tool/package_config.json tool/verify_three_phase_rotor.dart
flutter test --no-pub test/g5_lot_16_26_restore_test.dart test/c15_mode_wave2_test.dart
flutter test --no-pub test/energy_meter_runtime_test.dart test/energy_meter_contract_test.dart test/g5_lot_16_26_contract_test.dart test/g5_lot_16_26_runtime_test.dart
```

Aucun essai Mac Intel, Chromium, test à 400 composants ou secours hybride n'a été exécuté dans cette étape. La fusion électrique dans G5 est explicitement autorisée ; les contrôles GitHub et Mac restent attachés au candidat exact.
