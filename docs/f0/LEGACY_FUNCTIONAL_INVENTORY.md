# F0 - Inventaire fonctionnel de la référence historique

Référence: `ElectroSim-FIELDFIX01-R1.zip` — SHA-256 `569e05908592e6dd615bd80b342f6c7a28249850951d353dac988c5d2e1187bd`.

Version package historique: `14.31.15-eie08-r1-eie08ux04-r1-eie-mon03-r1-tp-sync01-r1-deenergized01-r3-meter01-energytime01-eiers14-tpflow03-r1-uic01-r1-palette01-r2-canvasactions01-r2-tpflow04-r1-sup04-r1-rpr03-r1-risk01-r1-pal04-r1-act03-r1-uic04-r1-propedit01-r1-nf03-r1-eie20mode01-r1-contact01-r1-contact02-r1-eie01r4-r1-eie0405-r1-eie08m-r1-eie03i-r2-eie07a-r1-fieldfix01-r1`.

Architecture observée: 137 scripts externes dans `teacher.html`, 128 dans `student.html`, 137 fichiers `electrosim_*.js/.ts` à la racine.

Le tableau ci-dessous décrit les capacités observées à conserver conceptuellement, sans convertir le code historique.

| Domaine historique | Preuves principales | Comportement utile à conserver | Décision F0 |
|---|---|---|---|
| Application professeur/élève | `teacher.html; student.html; B7 bootstraps` | Conserver rôles, parcours et séparation d’accès | Deux interfaces HTML chargent un grand graphe de scripts; reconstruction Flutter. |
| Modes électriques CC / AC1 / AC3 / PV | `electrosim_b5_core.js; electrosim_b5_ac3.js; electrosim_b5_pv.js; B11 engines` | Conserver les 4 domaines fonctionnels | Solveurs historiques servent d’oracle ponctuel, pas de code réutilisé. |
| Palette composants | `teacher.html; electrosim_palette01.js; B8 domain contracts` | Conserver recherche, accès rapide, Voir tous, cohérence visuelle | Catalogue réinventorié; aucun modèle électrique legacy importé automatiquement. |
| Câblage interactif | `electrosim_b532_connections.js; electrosim_b7_graphics_wiring.js; B10 interaction` | Conserver sélection, déplacement, bornes, wiring, zoom/pan | Refonte autour de GestureController/WiringController/HitTestEngine. |
| Nœuds/branches/mailles CC | `electrosim_b538_dc_topology.js; electrosim_b538_dc_analysis_ui.js` | Conserver analyse pédagogique KCL/KVL | Topologie devient indépendante du Canvas et du solveur. |
| Prises, cordons, appareils externes | `electrosim_b532_connections.js; electrosim_b53_appliances.js` | Conserver branchement explicite et états physiques | Unifier comme modèles de domaine; éliminer état visuel autoritaire. |
| Exemples câblés | `electrosim_b533_examples.js; circuit templates` | Conserver l’idée d’exemples sains chargeables | Aucun ancien exemple importé; bibliothèque repart de zéro. |
| Pannes / FaultEngine injection | `electrosim_b539_fault_catalog.js; electrosim_b539_fault_engine.js` | Conserver seulement la connaissance métier des types de défauts | Mécanisme d’injection abandonné; FaultScenario autonome avec faultyCircuitState. |
| TP câblage | `B55 TP activity/navigation; pedagogy` | Conserver consigne, progression, mesures, validation, évaluation | Nouvelle machine à états et validation physique via solveur. |
| Recherche de dérangement | `B55 troubleshooting; TPFLOW03/04` | Conserver démarche diagnostic/réparation et teacher truth privée | Charge directe d’un FaultScenario; aucune dépendance aux exemples. |
| Supervision professeur | `TP sync/live; closure/supervision` | Conserver progression, état terminé, score | État transactionnel de session; fin élève en lecture seule. |
| Mesures | `B11 measurements; C31 metrics; EIE07 measurement assistant` | Conserver multimètre et grandeurs utiles | MeasurementEngine indépendant; aucune valeur inventée par UI. |
| Énergie | `B5.4 clock/analyzer/history/session/dashboard/export` | Conserver W/Wh/kWh, pertes, rendement, historique | EnergyEngine neuf alimenté exclusivement par SimulationResult. |
| EIE / diagnostic | `EIE01..EIE20 modules` | Conserver explications contextuelles et localisation | DiagnosticEngine evidence-based; pas d’hypothèse présentée comme cause. |
| Sauvegardes locales | `electrosim_b55_local_saves.js` | Conserver sauvegardes multiples et liste Ouvrir | StorageRepository versionné, écritures atomiques, round-trip. |
| Exports PDF/CSV | `electrosim_b54_export.js; reporting` | Conserver exports séparés de Enregistrer | Refonte infrastructure; traçabilité engineVersion/circuitRevision. |
| Responsive/mobile | `mobile.html; UI V3 modules` | Conserver usages téléphone/tablette/desktop | Design system Flutter, profils compact/medium/expanded. |
| Visuels composants | `C31 raster/visual engine/palette animation` | Conserver objectif de réalisme/cohérence palette-platine | Assets peuvent inspirer visuellement; renderer Flutter reconstruit. |
| Command bus / coherence kernel | `B8 command bus/coherence kernel` | Conserver principe mutation contrôlée/revision | Reformulé en commandes/use cases et CircuitState immuable. |
| Déterminisme / audits | `NF03; master audits; regression sentinel` | Conserver culture de preuve et non-régression | Recréé en tests Dart/Flutter, property tests et rapports CI. |
| Globals, ordre de chargement, monkey-patches | `137 scripts; globals ElectroSim*; prototype wrappers` | Aucun comportement à conserver comme architecture | Abandon complet; dépendances explicites et couches strictes. |
| Compatibilité legacy / adaptateurs | `B7 compat bridge; B9 legacy adapter; B539 legacy adapter` | Conserver seulement comme documentation de comportements | Pas d’adaptateur runtime legacy dans le nouveau noyau. |

## Inventaire composants

217 entités ont été inventoriées comme connaissance de référence (195 composants palette, 4 prises, 18 appareils externes). Elles ne sont **pas importées** dans le catalogue Flutter.

Le détail se trouve dans `legacy_component_inventory.csv`.

## État de la dernière référence historique

La passation `FIELDFIX01-R1` déclare 376/376 contrôles automatisés PASS mais demande encore une validation physique Safari/iPhone avant promotion. Cette information est conservée comme contexte de comparaison, pas comme validation du nouveau projet.
