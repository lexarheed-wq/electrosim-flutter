# ElectroSim PNEU-DIR-001 — R1, contrat et plan détaillé (PRÉPARATION, NON EXÉCUTÉ)
Date : 2026-10-10. Directeur v1.0. Base documentaire R0 `2d8290529d669631c01601e19f5d81070362fa22`.
**Ne pas implémenter ni présenter R1 comme commencé avant le gate R0.** Ce plan sert à préparer les décisions d'architecture et les tests indépendants.

## 1. Entrée/sortie
**Entrée bloquante :** R0 qualifié sur un SHA unique, journal et manifeste incluant régressions et limites. S'assurer que PR #73 et #78 n'ont pas modifié des contrats liés. Le chef de projet décide de la fusion, pas du détail de l'implémentation.
**Sortie :** nouveau domaine pneumatique pure Dart, validateur de connexions strictement typées, enveloppe multiphysique versionnée, migrations non destructives v0/v1/v2, support de feature flag OFF par défaut, tests sans Flutter. Aucune pression, débit, force ni mouvement ne sera simulé par R1.

## 2. Base et règles d'identité
- `CircuitState.currentSchemaVersion == 1` doit rester intact. `SavedCircuitDocument.currentSchemaVersion == 2` sur G5 ; au démarrage R1, *revérifier* si P4 ou autre changement a déjà fait évoluer le stockage.
- Chaque appareil a un ID stable unique dans le registre du projet multiphysique. La sous-partie électrique d'un distributeur peut posséder un `ComponentId` mais reste rattachée au même appareil par un lien explicite et valide. Une correspondance par étiquette, nom, index de palette ou proximité est interdite.
- Les IDs réutilisés par erreur doivent être refusés, jamais renumérotés silencieusement. Le registre est typé domaine + ID de sous-partie ; il ne fait pas fusionner un port d'air avec un terminal électrique.
- Deux dispositions `platine` et `schema` sont distinctes, partageant appareils et sélection ; aucun état solveur ni position écran utilisée comme longueur de tuyau.

## 3. Fichiers à ajouter/modifier, interfaces pressenties
Les noms publics sont des propositions **à figer en revue R1-A** avant changement des contrats.

| Chemin exact | Responsabilité |
| --- | --- |
| `packages/electrosim_pneumatic_domain/pubspec.yaml` | package Dart, sans Flutter |
| `packages/electrosim_pneumatic_domain/lib/electrosim_pneumatic_domain.dart` | exports publics |
| `packages/electrosim_pneumatic_domain/lib/src/pneumatic_port.dart` | `PneumaticPort`, `PneumaticPortRole` (supply/work/exhaust/pilot), raccord nominal, pression admissible absolue |
| `packages/electrosim_pneumatic_domain/lib/src/pneumatic_device.dart` | `PneumaticDevice`, type de matériel et paramètres avec unités |
| `packages/electrosim_pneumatic_domain/lib/src/pneumatic_pipe.dart` | `PneumaticPipe`, deux IDs de ports, longueur, diamètre intérieur, volume, modèle de perte, défaut documenté |
| `packages/electrosim_pneumatic_domain/lib/src/pneumatic_network.dart` | `PneumaticNetwork`, validation topologique, jonctions explicites, ports uniques |
| `packages/electrosim_pneumatic_domain/lib/src/pneumatic_diagnostic.dart` | diagnostics structurés des contrats et unités |
| `packages/electrosim_multiphysics/pubspec.yaml` | dépend du domaine électrique et du domaine pneumatique, pas de Flutter/storage |
| `packages/electrosim_multiphysics/lib/src/multiphysics_project.dart` | `MultiphysicsProject` : `CircuitState` électrique + réseau d'air + couplages + layouts |
| `packages/electrosim_multiphysics/lib/src/electropneumatic_link.dart` | identité explicite bobine/contacts électriques ↔ appareils pneumatiques |
| `packages/electrosim_storage/lib/src/multiphysics_storage.dart` | enveloppe nouvelle, migrations sans écraser ancien enregistrement |
| `packages/electrosim_storage/lib/electrosim_storage.dart` | export complémentaire de la nouvelle enveloppe, sans changement API ancienne |
| `apps/electrosim/lib/runtime/` | R1 uniquement adaptateur OFF par défaut, aucune modification de `SolverDC`/`SolverAC` |
| `packages/*/test/pneumatics_*.dart` | tests de contrat/migration et rejeu des anciens corpus |
| `.github/workflows/pneumatics-r1-contracts.yml` | pipeline de non-régression et nouveaux tests en PR vers base qualifiée |

Aucun import des données V1 de pannes/schémas. Aucune reproduction constructeur certifiée.

## 4. Contrats de connexion
1. Électrique : `Connection` existant, `TerminalId`, `ElectricalMode`, règles existantes. Ne pas créer de nouvelles interdictions filaires arbitraires à l'intérieur du domaine.
2. Pneumatique : `PneumaticPipe(fromPortId, toPortId, lengthM > 0, innerDiameterM > 0, lossModel, faultState)`. Volumes morts et volume de tuyau distincts ; les ports possèdent des valeurs physiques d'admissibilité.
3. Un simple raccord n'admet pas plusieurs tuyaux sans être explicitement de type Té ou manifold. Une intersection dessinée sans Té est **non connectée**.
4. L'échappement ouvert communique à l'atmosphère ; un port bouché est hermétique ; une connexion physiquement rompue constitue un défaut distinct.
5. Les liens trans-domaines décrivent un **couplage**, jamais un tuyau ni un fil traversant les domaines. Une bobine ne doit pas être raccordée directement à `PneumaticPort`.
6. Les positions UI, le zoom et la géométrie des chemins écran ne modifient jamais `lengthM` ou la perte de charge.

## 5. Persistance, schémas, migrations
- Ne pas modifier ni réinterpréter silencieusement le `SavedCircuitDocument` historique (sur G5 v2). Proposer `SavedMultiphysicsDocument` dont les données électriques sont conservées à l'intérieur et dont l'enveloppe est versionnée indépendamment. Numéro initial envisagé : 3 **seulement si** la base définit encore 2 comme courant ; sinon réserver une nouvelle version et documenter la migration.
- `fromJson` accepte les anciennes entrées v0/v1/v2 via le décodeur actuel, les enveloppe avec réseau pneumatique et liens vides, conserve IDs, géométrie électrique et état d'application opaque.
- Les nouveaux projets se sérialisent sans perdre les ports, tuyaux, liens ou layouts. Toute version future inconnue retourne une erreur structurée ; jamais de réécriture automatique de l'original.
- L'état de session dynamique (masses, pressions, vitesses, position, commandes) n'entre pas dans le document de conception R1. Sa reprise relève d'instantanés versionnés qualifiés en R2/R3.
- Exporter l'ancien format est refusé pour un projet mixte qui contiendrait des données pneumatiques ou des liens. Un circuit électrique seul peut être exporté sans perte. Rétablir/annuler et duplication doivent passer les mêmes invariants d'identité.

## 6. Test indépendant, matrice de sortie
| ID | Précondition/action | Attendu |
| --- | --- | --- |
| R1-C01 | Port pneumatique vers terminal électrique | Refus immédiat sans mutation |
| R1-C02 | Port simple avec deux tuyaux concurrents | Refus ; ajout possible seulement via Té/manifold |
| R1-C03 | Deux tuyaux qui se croisent en vue platine | Aucune jonction créée |
| R1-C04 | Longueur m, diamètre m, pression absolue Pa invalides | Refus structuré ; jamais NaN/infini |
| R1-C05 | Absence de Té avant création d'une branche | Refus, pas de nœud implicite |
| R1-I01 | Distributeur unique avec sous-partie bobine | Identité physique unique, mapping explicite |
| R1-I02 | Bobine orpheline, capteur référant un appareil supprimé | Refus ou diagnostic conservé, pas d'activation fictive |
| R1-M01 | Sauvegarde v0/v1/v2 importée | IDs, paramètres, circuit, appState conservés ; air/liens vides |
| R1-M02 | Sauvegarde multiphysique → JSON → recharge | Équivalence structurelle, sans perte de liens |
| R1-M03 | Version future ou JSON malformé | Refus sans réécriture source |
| R1-M04 | Export legacy d'un projet mixte | Refus explicite de perte de données |
| R1-G01 | Extension OFF | Même chemin moteur électrique, régression DC/AC1/AC3/PV PASS |
| R1-G02 | Code Dart sans Flutter import et pas de cycles | Vérification statique PASS |

Les tests de R1 doivent être ajoutés **rouges avant implémentation** lorsque c'est possible, puis verts sur le commit final ; comparer indépendamment les JSON exacts de référence et les résultats du moteur électrique.

## 7. Risques, preuves et retour arrière
- Migration stockée partiellement modifiée par une PR parallèle : arrêter le stockage R1 et produire l'analyse de conflit sémantique ; les fichiers du moteur restent indépendants.
- Contrats imprécis de capteur/coil : décrire les points de couplage réels du moteur et figer les signatures avant leur usage en R3 ; une fausse animation ne peut pas remplacer l'implémentation.
- Toute refonte de widgets dans R1 viole la séparation des responsabilités.
- CI verte signifie tests exécutés sur le SHA du commit ; produire logs, test IDs, versions et limitations. Nouvel arbre après merge → tests à rejouer.
- Retour arrière : désactiver la feature, conserver le nouveau fichier de projet, ne jamais le rouvrir en mode legacy pour le réenregistrer. Aucune fusion de la branche utilisateur.

## 8. Décisions à enregistrer avant code
- R1-A : signatures publiques et naming des packages/modules.
- R1-B : stratégie exacte de format, schema version et migration compte tenu du dernier G5/P4.
- R1-C : représentation explicite des ensembles distributeur-bobines-capteurs et table de multiplicité des ports.
- R1-D : format de layouts indépendants et modèle de commande OFF par défaut.
La décision est consignée dans `docs/pneumatics/decisions/` avant modification des contrats. Cette proposition ne constitue pas une qualification R1.
