# R1 — revue de compatibilité et décisions proposées (préparatoire, non adoptées)
Date : 2026-10-10. PNEU-DIR-001 v1.0. **R0 n'est pas qualifié au moment de cette rédaction ; aucun contrat R1 n'a été modifié.**

## Sources et conflits à surveiller
- R0 PR #79 : branche `docs/pneumatic-r0-baseline-20261010`, base G5 `054c64f5d2c74bf9a7137c730b811968834543ee`. Son SHA évolue au gré des corrections ; relire son gate final.
- PR #73, head `7dd9c5b2d70ecba54d0b45054ca558c30e75eeb8` : un test de régression CC et un audit documentaire, aucun fichier de stockage ou de contrat partagé modifié dans la liste vérifiée. Pas de conflit direct de fichier R1 identifié.
- PR #78, head `5ed399b3d986095f1be5d125563f9516e2b660ca` : `industrial_marking_registry.dart`, `industrial_workspace_representation.dart`, `f18_workspace_page.dart`, exports et tests. **Conflit sémantique à prévenir** : `industrialMarkingV1` dans `CircuitState.metadata` est un registre de repères documentaires électriques, **pas** le registre d'identité des appareils multiphysiques. Ne pas recycler ces étiquettes comme clés physiques, ni les supprimer lors de migration.
- La PR #78 calcule une vue schématique électrique dérivée de la platine. R1 doit conserver sa projection intacte pour les projets électriques et stocker les deux dispositions **du nouveau projet** séparément ; ne pas écraser la vue électrique ni faire dépendre le tuyau du zoom.
- Base G5 vérifiée : `CircuitState.currentSchemaVersion=1`, `SavedCircuitDocument.currentSchemaVersion=2`. À revérifier immédiatement avant les écritures R1.

## Proposition R1-A — interfaces stables
Adopter deux packages Dart pur `electrosim_pneumatic_domain` et `electrosim_multiphysics`. `PneumaticPortId`, `PneumaticDeviceId`, `PneumaticPipeId`, `PhysicalDeviceId` sont des value types **distincts**, pas des alias de `TerminalId` ou `ComponentId`. Les unités SI apparaissent dans les noms de champs (Pa absolus, m, m², m³, kg). Éviter un `dynamic` opaque pour les liens et les ports. Les `PneumaticNetwork` restent immuables et validés à construction/désérialisation.

## Proposition R1-B — stockage versionné non destructif
Choisir un **type d'enveloppe distinct**, identifié par `documentType='electrosim-multiphysics'` et `schemaVersion=1` **dans cet espace de noms seulement**, plutôt que réutiliser `SavedCircuitDocument.schemaVersion=3`. L'ancien `SavedCircuitDocument` reste en v2 et conserve son décodeur v0/v1/v2. La migration d'un document legacy vers une nouvelle enveloppe est explicite et non destructive ; conserver l'original brut et `appState` opaque, notamment `industrialMarkingV1` dans le circuit. Le document mixte est refusé par un export legacy. Une version future inconnue n'est jamais ouverte en écriture.

Motif : numéroter une nouvelle famille de document à v3 dans le même champ sans discriminant confond l'évolution d'un format et la création d'une enveloppe ; le type discriminé permet d'identifier et refuser proprement un projet mixte par un ancien lecteur. Une éventuelle migration de stockage doit être testée contre de **vrais fixtures** v0/v1/v2, pas des JSON artificiellement rétrogradés uniquement.

## Proposition R1-C — identité et multiplicité
Chaque appareil est représenté par un `PhysicalDeviceId` stable. Une table `deviceBinding` associe explicitement ses éventuels `ComponentId` électriques, `PneumaticDeviceId` et capteurs ; un ID absent est refusé. La multiplicité des connexions dépend du port physique : raccord simple ≤1 tuyau, té/manifold multiport explicite ; un croisement géométrique ne crée aucun nœud. Les ports de valve de type alimentation/travail/échappement/pilotage sont des **rôles**, pas des permissions directionnelles qui interdiraient le retour de débit dans un passage réversible.

## Proposition R1-D — vues et activation
Deux layouts `plate` et `schematic` en coordonnées indépendantes, référencés par IDs d'appareils, avec sélection commune hors du modèle physique. `pneumaticFeatureEnabled=false` par défaut ; lorsque désactivé, le runtime électrique existant ne reçoit aucune nouvelle dépendance obligatoire et un document mixte est identifié comme non éditable sans perte, jamais converti silencieusement.

## Tests de revue préalables
1. Vérifier absence de conflit direct R1/PR78 et préservation du metadata `industrialMarkingV1` après import, save/reopen et export électrique.
2. Vérifier tous les `ValueId` : la regex électrique refuse les caractères hors `[A-Za-z0-9._:-]`; ne pas importer arbitrairement des ID avec espaces ou slash.
3. Tester export legacy d'un mixte : refus sans mutation. Tester export legacy électrique pur : équivalence du document.
4. Fixture ancienne v0/v1/v2 et JSON futur : préserver l'original, refuser les versions futures.
5. Vérifier deux vues sans mutation de `CircuitState`, et séparation des repères industriels de l'identité stable.

**Statut :** options recommandées, non figées. Enregistrer une ADR adoptée seulement après qualification R0 et revue des contrats finaux. Aucune PR R1 d'implémentation ne doit être ouverte sur cette seule préparation.
