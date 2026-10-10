# ElectroSim — Audit de couverture du cahier des charges post-V2 (P1 à P20)

**Date :** 10/10/2026  
**Référence de lecture :** `ElectroSim_Cahier_des_charges_fonctionnel_Post_V2(2)(2).pdf` (version 1.0 du 05/10/2026, 16 pages).  
**Dépôt audité :** `lexarheed-wq/electrosim-flutter`  
**Arbre audité :** `53485fde9f8ae410318713c2ee0b4453562ffaee` (fusion #70), branche `feat/g5-industrial-geometry-20261009`.  
**Nature :** revue statique du dépôt, des tests, des workflows et de leurs résultats connus. **Ce rapport n'est pas une recette physique sur Mac ni une certification constructeur.**

## 1. Convention de verdict

- **Présent / partiel** : fonctionnalité ou infrastructure identifiable en source, mais un ou plusieurs critères d'acceptation du cahier des charges ne sont pas démontrés.
- **Non identifié** : aucune implémentation correspondant au lot complet n'a été établie dans la branche auditée ; ne prétend pas démontrer mathématiquement l'absence de tout code expérimental.
- **Administrativement clôturé, réserve physique** : décision de progression distincte d'une qualification matérielle.
- **Qualifié** : à utiliser seulement lorsque tous les critères du lot, tests exact-SHA et validation finale requise sont prouvés.

Un test vert de solveur, une réussite du pipeline GitHub ou un aperçu graphique **ne prouve pas** l'ensemble des exigences physiques et industrielles.

## 2. Inventaire des vingt lots

| Lot | Couverture constatée au SHA audité | Ce qui manque pour la clôture | Verdict |
|---|---|---|---|
| **P1 — Moteur et câblage** | Tests de sources CC série/parallèle, polarisations, KCL/KVL, séparation Canvas/solveurs/EIE ; documentation de clôture de planification et suites physiques PHYS-Q2. | Recette physique sur Mac Ventura ; élargir qualification réelle protection/moteur et rester vigilant aux approximations constructeur. | **Administrativement clôturé ; réserve physique** |
| **P2 — Implantation d'armoire** | Rails DIN, goulottes, zones de borniers, armoire dimensionnée, surfaces intérieur/porte/extérieur, attaches, placement assisté, collisions, routage multi-goulottes, édition/Undo/Redo, persistance schéma 3 et aperçu 3D générique. | Campagne complète sur armoire chargée avec tous modes, borniers physiques associés électriquement, performance mesurée, validation visuelle et réelle sur Mac. | **Avancé, non qualifié totalement** |
| **P3 — Schéma normalisé** | Vue `Platine / Schéma`, projection symbolique dérivée sans altérer `CircuitState`, fond blanc, projections de bornes, quelques tests. | Conformité des symboles/repères, schéma multifilaire industriel complet, renvois bobine/contact, navigation croisée qualifiée, export PDF/SVG du schéma. | **Partiel** |
| **P4 — Repérage automatique** | Noms/identifiants de bornes et de composants existants. | Générateur Q/F/KM/KA/S/H/M/X, numérotation des fils, anticollision de repères, verrouillage manuel, références croisées. | **Non identifié comme fonction complète** |
| **P5 — Instrumentation avancée** | Mesures moteur, volt/amp physiques, fréquence et ordre des phases, mesures AC1/AC3/PV et états de sonde. | Oscilloscope 2/4 voies fondé sur séries temporelles, curseurs, enregistreur, analyseur de réseau P/Q/S complet, harmoniques sans invention de traces. | **Partiel** |
| **P6 — Commande moteur avancée** | Moteur DC à dynamique simplifiée ; contacteur triphasé, NO/NC, auto-maintien, Y/Δ sous enveloppe R-L et classes thermiques approximatives. | Démarreur étoile-triangle automatique complet, inverseur, soft starter, variateur de fréquence, couple/glissement et modèles de démarrage/défauts validés. | **Partiel** |
| **P7 — API/PLC/Ladder** | Aucune chaîne PLC + langage Ladder validée identifiée. | API virtuel, cycle déterministe, TOR, temporisateurs/compteurs, édition Ladder, connexion bornes. | **Non identifié** |
| **P8 — Pneumatique/électropneumatique** | Pas de moteur pneumatique et de couplage certifiés identifiés. | Vérins, distributeurs, électrovannes, pression/débit, moteur pneumatique indépendant et interface états. | **Non identifié** |
| **P9 — Bibliothèque professionnelle** | Palette conséquente, contrats canoniques/paramètres et bibliothèques natives V2 séparant exemples sains et pannes. | Éditeur complet de composants personnalisés, validation de packs/versionnement et import/export de références. | **Partiel** |
| **P10 — EIE professeur/audit TP** | EIE interne adossé aux preuves topologie/solveur, professeur uniquement, sans modification des résultats. | Audit complet d'activité avant publication, incohérences pédagogiques, confiance/justification et détectabilité/réparabilité systématique des pannes. | **Partiel** |
| **P11 — Créateur graphique de pannes** | Scénarios défectueux natifs V2 autonomes (deux scénarios de première vague), sans dépendance à un exemple sain ; repository/validator. | Interface graphique professionnelle de création, pannes paramétriques/intermittentes, validation complète EIE avant publication. | **Partiel** |
| **P12 — Historique tentatives élève** | Historique append-only de diagnostic via le LAN et états de supervision. | Journal structuré des mesures, gestes/réparations et durée, comparaison de deux tentatives, restitution et règles de confidentialité. | **Partiel** |
| **P13 — Examen verrouillé** | Contrôle des états TP `submitted/evaluated/closed` et lecture seule après remise. | Épreuve chronométrée avec ouverture programmée, verrous inviolables et validations d'examen/reconnexion. | **Partiel (socle de verrouillage TP)** |
| **P14 — Rapports PDF/DOCX** | `ExportService.toPdf()` produit un PDF d'une page listant seulement titre, saveId, circuit, révision, mode et moteur ; `toCsv()` exporte un résumé. | Véritable rapport schéma/implantation, nomenclature, fils, mesures, diagnostic, note et observations ; DOCX absent de cette fonction. | **Partiel minimal** |
| **P15 — Mode projet/nomenclature** | Métadonnées de projet et dénombrement sommaire dans l'export CSV. | Nomenclature par référence, quantités/calibres, numérotation des conducteurs, borniers, longueurs et export métier. | **Partiel minimal** |
| **P16 — Collaboration temps réel** | Synchronisation professeur/élèves Web/LAN, reconnexion et snapshots sous autorité enseignant. | Coédition d'une même platine, gestion des conflits, verrouillage collaboratif et arbitrage déterministe. | **Socle réseau, collaboration non qualifiée** |
| **P17 — Undo/Redo professionnel** | Historique visuel d'édition de l'atelier, Undo/Redo (capacité bornée), sauvegarde de géométrie. | Points de restauration nommés, comparaison d'états, versionnage TP, reprise transversale robuste. | **Partiel** |
| **P18 — Grands circuits/performance** | Tests/benchmarks de canvas et de routage, solveurs par îlots côté CC. | Profilage soutenu en centaines de composants, recalcul incrémental, budgets prouvés, virtualisation canvas si nécessaire. | **Partiel** |
| **P19 — 3D/AR** | Aperçu 3D générique d'armoire orientable, en lecture seule, partageant `CircuitState`. | AR, calibration/validation immersive et couverture visuelle complète des références. | **Partiel, basse priorité** |
| **P20 — Interopérabilité CAO** | Formats locaux, CSV/PDF sommaires. | Formats industriels documentés de connexions/nomenclature, export schéma PDF/SVG, import strict versionné et contrôle de pertes. | **Partiel minimal** |

**Résultat :** aucun des vingt lots ne reçoit ici le verdict « qualifié intégralement » au sens strict du cahier des charges. Cela ne signifie **pas** que tous les lots sont absents : P1 et P2 ont une couverture substantielle, P3/P5/P6/P9/P17 ont déjà des fondations utiles.

## 3. Preuves principales consultées

- Architecture moteur : `apps/electrosim/lib/runtime/electrosim_runtime_engine.dart`, `packages/electrosim_solver_dc/`, `packages/electrosim_solver_ac/`, `packages/electrosim_pv/`, `packages/electrosim_diagnostics/`.
- Clôture P1 : `docs/postv2/p1/POSTV2_P1_PROJECT_CLOSURE_20261009.md` (indique explicitement l'absence d'attestation `POSTV2_P1_PHYSICAL_MAC_PASS`).
- P2 et P3 : `apps/electrosim/lib/f18_workspace_page.dart`, `industrial_cabinet_workspace.dart`, `industrial_workspace_representation.dart`, `packages/electrosim_canvas/lib/src/cabinet_layout.dart`, `cabinet_duct_wire_planner.dart`, `apps/electrosim/lib/runtime/electrosim_layout_persistence.dart`.
- Essai intégré P2 : `apps/electrosim/test/industrial_workflow_test.dart` (auto-maintien AC3, armoire/schéma, câblage, persistance, invariants de commande).
- Qualification multipolaire : `apps/electrosim/test/multipole_overload_realistic_qualification_test.dart` (B/C/D et classes thermiques pédagogiques, moteur 6 bornes, 3P/4P).
- Instrumentation : `apps/electrosim/test/physical_families_instruments_dynamics_qualification_test.dart` et `packages/electrosim_measurements/lib/src/measurement_engine.dart`.
- Exports : `packages/electrosim_storage/lib/src/export_service.dart`.
- Pannes V2 : `packages/electrosim_scenarios/lib/src/v2_product_examples.dart` et `v2_product_faults.dart`.
- LAN/TP : `apps/electrosim/lib/runtime/electrosim_lan_sync.dart`, `packages/electrosim_tp/lib/src/tp_engine.dart`.
- CI : `.github/workflows/g5-industrial-geometry-qualification.yml`, `.github/workflows/electrosim-physical-matrix-audit.yml`.

## 4. Écarts bloquants et plan de reprise

### Blocage de qualification P1

Le chef de projet a validé la progression vers P2 ; cette décision est conservée. Toutefois, il manque toujours une attestation de **recette physique P1 sur Mac Ventura**. Les résultats numériques PHYS-Q2 décrivent des enveloppes et non les courbes de produits certifiés.

### Priorité immédiate : fermer P2 avant d'ouvrir un nouveau grand lot

1. Protéger par tests le principe **toute édition d'armoire, de rails, de goulottes et tout changement Platine/Schéma ne modifient jamais la topologie ni les grandeurs électriques**.
2. Tester des circuits alimentés CC et AC3 (existants) puis étendre aux cas AC1 et PV, y compris appareils/sondes.
3. Tester le chemin complet utilisateur composant → rail → déplacement → câblage multi-goulottes → sauvegarde → réouverture → Undo/Redo, avec collisions.
4. Évaluer de vrais borniers physiques/électriques, puis mesurer les performances d'armoires chargées et documenter les seuils.
5. Construire candidat Mac Intel + preuves Flutter/Chromium du SHA qualifié, et demander la recette physique Ventura uniquement après élimination des erreurs automatiques.

**Premier correctif de couverture ajouté sur la branche d'audit :** `apps/electrosim/test/postv2_p2_dc_live_isolation_test.dart`, essai widget d'une charge CC réelle avec configuration d'armoire, routage via goulottes, passage Platine/Schéma, sauvegarde de géométrie et comparaison tension/courant/puissance.

### Après P2

P3 : fermer la normalisation et l'export déterministe du schéma ; P4 : repérage automatique ; P5 et P6 : instrumentation/commande moteur selon modèles temporels qualifiés ; P9 : bibliothèque paramétrable extensible ; P10 à P20 suivant dépendances et priorités du cahier des charges, sans anticiper TP/élèves au détriment du moteur physique.

## 5. Règles d'acceptation

- Un verdict `PASS` doit désigner un scénario mesuré avec hypothèses, tolérances et SHA. Distinguer `FAIL`, `NON RÉSOLU`, `NON MODÉLISÉ`, `NON QUALIFIÉ`.
- Pas de correction par nouvelle couche électrique parallèle dans le Canvas.
- Pas de baisse artificielle de couverture pour verdir CI.
- Ne pas réimporter les bibliothèques de schémas/pannes V1.
- Toute PR de progression doit passer analyse Flutter, tests ciblés, régressions CC/AC1/AC3/PV et build Mac adapté ; la clôture physique exige un essai réel.
- **Interprétation de cet audit :** le niveau d'avancement d'un lot ne se déduit ni du nom de sa branche ni d'une CI verte isolée.
