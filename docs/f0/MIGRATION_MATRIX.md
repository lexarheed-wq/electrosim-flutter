# F0 - Matrice de migration fonctionnelle

Règle: **aucune ligne ne signifie copie de code**. « Reprise » = connaissance/comportement à réexprimer et retester.

| Ancienne fonctionnalité | Nouveau module | Reprise | Refonte | Abandon | Justification |
|---|---|---|---|---|---|
| Shell professeur/élève HTML | Presentation / Flutter UI | Parcours/rôles | Oui | HTML/CSS/JS shell | Flutter remplace les pages historiques. |
| État de circuit legacy | electrosim_domain / CircuitState | Concepts électriques | Oui | Copies mutables concurrentes | CircuitState devient source unique versionnée. |
| Solveur CC historique | electrosim_solver_dc | Cas de comparaison | Oui | Algorithmes/runtime legacy | MNA neuf et déterministe. |
| Solveur AC1 historique | electrosim_solver_ac | Cas de comparaison | Oui | Algorithmes/runtime legacy | Phasors/complexes et P/Q/S/cosφ explicitement testés. |
| Solveur AC3 historique | electrosim_solver_ac | Cas de comparaison | Oui | Approx./branches legacy | L1/L2/L3/N explicites; déséquilibres natifs. |
| PV historique | module PV + electrosim_energy | Comportements attendus | Oui | État UI/solveur legacy | PV et onduleur re-modélisés physiquement. |
| Catalogue composants | electrosim_domain ComponentModels | Noms/familles comme inventaire | Oui | Import automatique des modèles | Chaque composant sera réintroduit avec contrat + tests. |
| Canvas/câblage JS | Simulator Interaction + Rendering | Gestes et ergonomie | Oui | Moteur graphique DOM | Flutter Canvas/CustomPainter + hit-testing centralisé. |
| Analyse nœuds/branches | TopologyEngine | Concept pédagogique | Oui | Implémentation legacy | Graphe canonique indépendant du rendu. |
| Mesures | MeasurementEngine | Grandeurs/instruments | Oui | Lecture directe UI/états | Mesures uniquement depuis SimulationResult. |
| Prises/cordons/appareils externes | Domain + UI interaction | UX de branchement | Oui | Double représentation électrique | Modèles explicites intégrés au circuit. |
| Bibliothèque Exemples | electrosim_scenarios / ExampleRepository | Principe seulement (circuit sain) | Oui | **Tous les items, données, titres, IDs et circuits V1** | Reconstruction intégrale depuis zéro dans Flutter; aucun schéma V1 n’est importé, converti ou utilisé comme entrée de génération. |
| FaultEngine par injection | Aucun | Taxonomie de défauts seulement | Oui | FaultEngine injection | Architecture interdite par le cahier des charges. |
| Bibliothèque Pannes | electrosim_scenarios / FaultScenarioRepository | Principe seulement (scénario autonome) | Oui | **Tous les items, données, titres, IDs, circuits et teacher-truth V1** | Reconstruction intégrale depuis zéro; aucun scénario V1 n’est importé, converti ou utilisé comme entrée de génération. Chaque panne finale possède directement son faultyCircuitState. |
| TP câblage | Application / TPEngine | Flux pédagogique | Oui | Orchestration legacy | Validation structurelle/fonctionnelle réelle. |
| Recherche de dérangement | Application / TPEngine + FaultScenario | Démarche diagnostic | Oui | Ponts exemple+panne | FaultScenario chargé directement. |
| Teacher truth | Policy sécurité pédagogique | Principe de confidentialité | Oui | Payloads/masquages legacy | Données privées jamais envoyées à l’élève. |
| Énergie B5.4 | electrosim_energy | Fonctions W/Wh/kWh/pertes/rendement | Oui | Calculs couplés legacy | Moteur indépendant basé sur résultats physiques. |
| EIE historique | electrosim_diagnostics | Intentions pédagogiques | Oui | Règles heuristiques non prouvées | Evidence IDs et diagnostics traçables. |
| Sauvegardes | electrosim_storage | UX Enregistrer/Ouvrir | Oui | Format legacy | Schémas versionnés, atomicité, migrations explicites. |
| Exports PDF/CSV | Infrastructure export | Fonctions d’export | Oui | Code export legacy | Export séparé de la sauvegarde. |
| Palette/recherche/Voir tous | electrosim_ui_kit | Ergonomie | Oui | DOM handlers legacy | Widgets Flutter testés tap/latence. |
| Responsive/mobile | electrosim_ui_kit | Intentions responsive | Oui | mobile.html spécifique | Profils compact/medium/expanded. |
| Globals et ordre de scripts | Composition root / DI | Aucune | Oui | globals, load order | Dépendances explicites; noyau sans UI. |
| Monkey-patches/prototype overrides | Aucun | Aucune | Oui | patching runtime | Interdit; extensions par interfaces/composition. |
| Adaptateurs legacy | Aucun runtime | Documentation seulement | Oui | compat bridges | Pas de couche de compatibilité dans le nouveau noyau. |
| Audits/régression | tools + CI | Principe et cas utiles | Oui | Scripts historiques tels quels | Nouveaux audits statique/solveur/catalogue/UI/storage/sécurité. |
