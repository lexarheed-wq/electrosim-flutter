# ElectroSim — Document directeur pneumatique et électropneumatique

Version 1.0 — 10 octobre 2026 — Référence : PNEU-DIR-001.

## 1. Mandat, portée et statut

Construire dans ElectroSim un atelier pneumatique et électropneumatique
quantitatif, utilisable en formation et pour l'étude fonctionnelle de montages
industriels. Les pressions, débits, déplacements et commandes doivent provenir
des modèles physiques ; la platine réaliste et le schéma représentent le même
projet et les mêmes résultats.

Le principe d'intégration a été validé par l'utilisateur. Ce document formalise
la direction architecturale et les règles de pilotage ; il ne constate aucune
implémentation pneumatique et ne remplace pas les plans détaillés de chaque lot.
Les objectifs ci-dessous sont des exigences à qualifier, pas des performances
déjà obtenues. La prochaine étape est la revue de ce document, puis le plan R0/R1.

Périmètre initial : air comprimé, composants génériques documentés, commandes
électriques 24 V CC, un vérin simple ou double effet et des distributeurs
discrets. Hors première livraison : hydraulique, CFD 3D, analyse acoustique,
automate programmable, distribution de puissance multiréseaux électriques,
servopneumatique, qualification de sécurité et reproduction fabricant certifiée.
Ces éléments pourront faire l'objet de programmes séparés.

La simulation n'est pas une certification de dimensionnement ou de sécurité
d'une machine réelle. La fidélité physique déclarée doit correspondre aux
modèles effectivement intégrés, notamment pour le thermique et les frottements.

## 2. Référence de départ et constat du code

Audit effectué sur `feat/g5-industrial-components-next-20261009`, commit
`7f8d8a2763b529767c4bac95fd19ccf2646d18e4`. Ce commit n'est pas présenté comme
la branche la plus avancée du dépôt. La branche documentaire est séparée.
Les PR de rendu et de platine restent non fusionnées dans ce contexte.

| Point d'intégration existant | Constat | Conséquence |
|---|---|---|
| `apps/electrosim/lib/f9_component_palette.dart` | Catalogue et filtrage par `ElectricalMode` | Distinguer famille technologique et mode électrique |
| `packages/electrosim_domain/lib/src/electrical_types.dart` | Modes CC/AC1/AC3/PV, rôles et conducteurs électriques | Créer des ports et liens pneumatiques typés |
| `packages/electrosim_topology/lib/src/topology_engine.dart` | Les conducteurs réunissent leurs extrémités en nœuds | Un tuyau à pertes et volume ne peut pas être un fil idéal |
| `apps/electrosim/lib/runtime/electrosim_runtime_engine.dart` | Projection, compilation topologique et solveurs électriques | Ajouter un orchestrateur sans faire entrer l'air dans les solveurs électriques |
| `apps/electrosim/lib/runtime/electrosim_simulation_controller.dart` | Pas de 100 ms par défaut, calcul appelé depuis le contrôleur | Sous-pas physiques et exécution séparée du rendu |
| `packages/electrosim_domain/lib/src/circuit_state.dart` | Schéma électrique version 1, lecture stricte | Conserver ce format lors de l'enveloppement multiphysique |
| `packages/electrosim_storage/lib/src/storage_models.dart` | Document enregistré version 2, migrations 0/1 existantes | Faire migrer la sauvegarde sans perdre les anciens circuits |
| `packages/electrosim_canvas/lib/src/` | Géométrie, routage, platine et supports existants | Étendre les présentations et préserver le câblage électrique |
| `apps/electrosim/lib/f18_industrial_dual_view.dart` | Perspective palette et face avant platine | Réutiliser ce contrat de présentation pour les nouveaux appareils |

Les 425 tests électriques réussis et les preuves du lot précédent sont une
référence historique de ce commit. R0 doit les rejouer sur la base effectivement
retenue : ni ce nombre ni un ancien rapport ne qualifient une nouvelle branche.
La bibliothèque de schémas existante ne prouve pas qu'une édition schématique
normalisée synchronisée avec la platine est déjà disponible.

## 3. Principes non négociables

1. Une seule autorité physique : les widgets consomment les résultats, ils ne
   décident ni pression, ni débit, ni déplacement, ni état de distributeur.
2. Chaque connexion possède un domaine. Un fil ne peut pas devenir un tuyau
   par simple couleur, et une bobine n'est jamais raccordée directement à un port d'air.
3. Les identifiants d'appareils sont stables ; les deux vues ne créent pas deux
   copies électriques/pneumatiques d'un même appareil.
4. L'extension pneumatique désactivée conserve le chemin électrique existant.
5. Les modèles scientifiques publient paramètres, unités, hypothèses, domaine
   de validité et références. Une photo ne valide pas un modèle physique.
6. Le temps physique et les événements sont déterministes ; aucun calcul
   scientifique ne dépend de la fréquence des images ou d'un effet visuel.
7. Une donnée invalide ou une non-convergence produit un diagnostic explicite,
   jamais une animation de réussite ni des résultats remplacés silencieusement par zéro.
8. Les preuves sont produites par le code livré, associées à son SHA et à la
   version des modèles ; les captures générées ou retouchées ne sont pas des preuves produit.
9. Les fichiers de référence électrique et les anciens projets sont conservés.
10. La première qualification porte sur des composants génériques : aucun
    comportement spécifique à un fabricant ne doit être inventé.

## 4. Architecture retenue

### 4.1 Modules et responsabilités

Les chemins nouveaux indiqués ici sont une architecture cible, pas des fichiers
existants. Les noms publics et signatures détaillées seront figés dans le plan
R1 avant développement ; ils ne doivent pas diverger entre lots.

| Module cible | Responsabilité | Dépendances permises |
|---|---|---|
| `packages/electrosim_pneumatic_domain/` | Ports, tuyaux, composants, unités, paramètres et diagnostics structurés | Dart, dépendances de données explicitement justifiées ; aucun Flutter |
| `packages/electrosim_pneumatic_solver/` | Réseau compressible, états thermodynamiques, débit et mécanique | Domaine pneumatique ; aucun widget, stockage ou lecteur audio |
| `packages/electrosim_multiphysics/` | Projet commun, liens de couplage et orchestration des événements | Domaines électrique/pneumatique et interfaces des moteurs |
| `apps/electrosim/lib/runtime/` | Adaptation du moteur électrique existant, ordonnanceur et worker | Modules physiques ; pas de géométrie de rendu dans les modèles |
| `packages/electrosim_storage/` | Enveloppe de projet, migrations et import/export | Modèles sérialisables ; pas d'appel aux solveurs pendant la lecture |
| `apps/electrosim/lib/pneumatics/` | Palette, inspecteurs et instruments pneumatiques | Résultats et catalogue ; jamais le calcul des forces |
| `packages/electrosim_canvas/` | Ports affichés, tuyaux, sélection et deux dispositions | Contrats de géométrie ; pas de dépendance au solveur pneumatique |

Une dépendance cyclique, ou l'import de Flutter dans un solveur, bloque le lot.
Le projet multiphysique doit pouvoir être simulé sans lancer l'interface.

### 4.2 Projet et identité

L'enveloppe de projet contient : le `CircuitState` électrique inchangé, le
réseau pneumatique, les liens électropneumatiques et deux dispositions graphiques.
Un registre de projet associe chaque appareil physique à ses représentations
et à ses éventuelles sous-parties électriques/pneumatiques.

Un distributeur électropneumatique possède un identifiant d'appareil, des ports
d'air et une ou deux bobines référencées explicitement. Une bobine électrique
et un contact de capteur restent des éléments électriques valides reconnus
par les contrats du moteur électrique. Les liens ne sont jamais déduits du
nom affiché, de la proximité graphique ou d'un numéro de palette.

L'air comprimé n'est pas une nouvelle valeur de `ElectricalMode` : un projet
24 V CC peut contenir simultanément un circuit pneumatique. R1 ne doit pas
promettre des sous-réseaux DC et AC simultanés que l'architecture actuelle
exclusive par mode ne prend pas encore en charge.

### 4.3 Contrats de connexion

- Port électrique : rôle, polarité/phase et contraintes existantes.
- Port pneumatique : alimentation, travail, échappement ou pilotage,
  raccord nominal et pression admissible.
- Tuyau : deux extrémités, longueur, diamètre intérieur, modèle de perte,
  volume et condition de défaut. La longueur physique n'est pas déduite du zoom.
- Té/manifold : jonction explicite pour plusieurs tuyaux ; en vue physique,
  un raccord simple n'accepte pas implicitement dix tuyaux.
- Une intersection visuelle de tuyaux ne crée pas une jonction.
- Un échappement ouvert communique avec l'atmosphère ; un port bouchonné
  et un tuyau débranché n'ont pas le même comportement.

La validation de connexion est centralisée et testée dans les deux vues.
Les erreurs de raccordement électrique intra-domaine existantes ne doivent
pas être interdites arbitrairement : elles restent interprétées par le moteur.
En revanche, une connexion entre domaines incompatibles est refusée immédiatement.

## 5. Contrat scientifique du premier moteur

### 5.1 Unités et hypothèses

Calcul en SI : Pa absolus, kg, m, s, K, débit massique kg/s. L'interface peut
afficher bar relatifs, mm, N et litres normalisés par minute.
Atmosphère de référence : 101 325 Pa ; 1 bar = 100 000 Pa.
Air sec générique : constante spécifique 287,05 J/(kg·K).
Hypothèse initiale : gaz parfait isotherme à 293,15 K. La température est un
paramètre de modèle déclaré, pas une température mesurée calculée.
La conversion en Nl/min utilise explicitement 273,15 K et 101 325 Pa ; ces
conditions de référence sont visibles dans l'instrument et les exports.

Chaque famille dispose d'une fiche scientifique versionnée. Les coefficients
de débit, frottements et seuils de bobine doivent être documentés. En l'absence
de données fabricant, des paramètres pédagogiques génériques sont autorisés
et signalés ; aucune valeur arbitraire ne sera présentée comme une référence constructeur.

### 5.2 Pression et débit

Pour chaque volume : masse d'air positive, volume strictement positif et
relation `p_abs * V = m * R * T`. La masse évolue selon la somme des débits
entrants et sortants. Les volumes morts d'un vérin évitent la singularité
en butée. Les pressions et masses sont des états physiques, pas des couleurs.

Les passages de distributeurs et restrictions utilisent un modèle compressible
documenté prenant en charge les régimes subsonique et sonique. Les paramètres
ISO 6358 peuvent être utilisés avec une référence explicite ; ne pas annoncer
une conformité normative sans vérifier les équations et les conditions d'essai.
L'inversion du gradient doit inverser le débit d'un passage bidirectionnel.
Un clapet obéit à son sens et à sa pression d'ouverture.

R2 utilise une alimentation régulée idéale, annoncée comme telle. Les pertes
des tuyaux sont calculées ; leur volume peut être représenté par volumes
concentrés. La propagation acoustique détaillée dans les longues conduites
n'est pas incluse. Réservoir, compresseur et régulateur non idéal relèvent de R5.

### 5.3 Mécanique du vérin

État : position, vitesse et masses d'air des deux chambres. Paramètres : diamètre
du piston, diamètre de tige, course, volumes morts, masse déplacée, charge,
frottements et amortissement lorsqu'il est pris en charge.

Force pneumatique en pressions relatives :
`F = p_A_rel * A_piston - p_B_rel * (A_piston - A_tige)`.
L'accélération résulte de cette force diminuée de la charge et des frottements.
Un vérin simple effet ajoute un ressort documenté. La course est bornée
physiquement ; l'intégrateur doit traiter la collision et son bilan, pas
simplement masquer le dépassement dans l'image.

Cas analytique de référence : diamètre 32 mm, pression relative côté plein
600 000 Pa, côté opposé à l'atmosphère, frottements nuls : force théorique
482,55 N à ±0,5 N. En rentrée, la surface utile est réduite par la tige.
Un vérin sous-alimenté ou trop chargé peut s'arrêter avant la fin de course.

### 5.4 Distributeurs et commandes

Chaque distributeur définit la table de passage de chaque position, les
échappements, le rappel éventuel, les délais et le comportement des commandes
opposées. Les états transitoires doivent être déclarés dans la fiche de modèle.
Un 5/2 monostable et un 5/2 bistable ne partagent pas une règle de retour implicite.

Les bobines utilisent la tension réellement calculée et un modèle électrique
documenté, avec seuils de prise/retombée et hystérésis. La force magnétique
détaillée n'est pas promise dans R3. Les capteurs ont zone, hystérésis et délai
éventuel ; leur contact suit la position calculée, jamais la fin d'une animation.
Les capteurs NO/NC réutilisent des contacts électriques reconnus. Les capteurs
trois fils PNP/NPN et l'électronique d'automate sont hors R3.

### 5.5 Arrêts et défauts

Pause : geler le temps physique et les états ; reprise sans remise à zéro.
Réinitialisation : revenir à l'état initial explicite du scénario.
Couper le 24 V : retirer l'excitation électrique, sans effacer l'air emprisonné.
Couper l'air : appliquer le comportement de la vanne d'alimentation concernée,
sans assimiler fermeture et mise à l'échappement.
Les pressions emprisonnées, la fuite, l'échappement bouché, le tiroir bloqué
et les défauts électriques doivent avoir des comportements distincts.

## 6. Temps, couplage et calcul parallèle

L'horloge globale donne le temps simulé ; le rendu ne lui donne pas le temps.
Les 100 ms du contrôleur actuel ne deviennent pas le pas du moteur pneumatique.
Le moteur avance par sous-pas adaptatifs avec localisation des commutations,
des seuils et des fins de course. Le plan R2 fixera la méthode d'intégration,
les tolérances et la plage de pas après des essais sur les réseaux raides.
Ces essais constituent une décision technique R2-A documentée avant qualification.

Au début d'un sous-pas, résoudre le circuit électrique avec les états de
contacts courants ; calculer la commande des bobines ; avancer l'air et la
mécanique jusqu'au prochain événement ; mettre à jour les capteurs et re-résoudre
les changements discrets à cet instant. Une re-résolution à temps nul n'avance
pas une seconde fois les chambres, la mécanique ou les protections électriques.

Les événements simultanés sont traités dans un ordre stable documenté. Une
boucle de commutations ne converge pas par attente infinie : limiter les
itérations, réduire le sous-pas avec retour à l'état accepté, puis produire
un diagnostic si la stabilisation reste impossible. L'état accepté et le temps
affiché ne peuvent pas être incohérents après un échec.

Calcul natif : isolate persistant. Web : worker réellement exécuté hors du
fil graphique, à qualifier ; ne pas considérer `compute` comme une preuve
d'exécution parallèle Web. Protocole de messages avec révision de projet,
numéro de requête et version du moteur ; ignorer les réponses devenues obsolètes.
Limiter la file à une demande active et une mise à jour remplaçable. Annulation,
fermeture de projet et erreur de worker doivent libérer les ressources.

Une modification graphique n'invalide pas le réseau physique. Les changements
de connexion et de paramètres sont classés pour invalider seulement les
structures concernées. Une commutation de distributeur met à jour ses passages
sans reconstruire tous les identifiants et dispositions. Les changements de
contacts électriques suivent les règles de compilation du moteur existant.

L'avance accélérée utilise les mêmes exigences de stabilité que le temps réel.
Les pas de 1 s, 30 s ou 5 min du contrôleur électrique actuel ne sont pas
transposés aux vérins ; l'accélération augmente le calcul par unité de temps
réel, pas l'erreur physique autorisée. L'interface conserve l'annulation.

## 7. Interface et rendu

Un sélecteur de famille propose Électrique, Pneumatique et Électropneumatique.
Le mode CC/AC reste une propriété électrique distincte. Les composants hors
périmètre ne sont pas affichés comme simulables.

Les deux vues possèdent des dispositions indépendantes et une sélection commune :

- Platine : fond métallisé conservé, appareils frontaux, palette en perspective,
  tuyaux avec raccords réalistes, supports de vérins et embases de distributeurs.
- Schéma : symboles pneumatiques fondés sur ISO 1219 et conventions électriques
  IEC appropriées ; construction originale ou ressources dont la licence autorise l'usage.
- Inspecteur : paramètres, limites de validité et valeurs calculées séparés.
- Mesures : pression de chaque chambre, débit, position, vitesse, force et
  consommation ; courbes synchronisées sur le temps simulé.
- Commandes : lancer, pause, pas à pas, ralenti, remise à l'état initial.

Les repères `1/P`, `2/A`, `4/B`, `3/R`, `5/S` sont appliqués selon la fiche
du distributeur. Les tuyaux montrent une légende de pression et, si demandé,
des flèches de débit. Une conduite sous pression avec débit nul n'anime pas
un flux fictif. La couleur seule n'identifie pas un état : valeur, repère ou
forme restent accessibles. Le repère de borne reste utilisable au zoom faible.

Les images immuables sont partagées ; les parties mobiles sont séparées.
L'animation interpole des états acceptés sans extrapoler une fin de course non
calculée. Boîtier, fixation et bornes ne se déplacent pas avec le tiroir ou la
tige. Le son d'échappement, facultatif et désactivable, dépend du débit d'air,
sans prétendre prédire un niveau acoustique industriel.

## 8. Persistance, coexistence et activation

Créer une nouvelle enveloppe de sauvegarde versionnée pour le projet
multiphysique, en conservant `CircuitState` v1 à l'intérieur pour R1. Les
anciens documents enregistrés v0/v1/v2 migrent vers un projet avec réseau
pneumatique vide, liens vides et disposition électrique conservée.

La nouvelle version du document stocké sera définie dans R1 en tenant compte
de la base réellement retenue ; ne pas imposer aveuglément « v3 » si une autre
branche a déjà fait évoluer le format. La lecture d'une version future refuse
proprement l'ouverture et ne réécrit jamais l'original.

Séparer paramètres de conception et état de session. L'ouverture d'un projet
démarre en pause. La reprise de masses, pressions et vitesses n'est proposée
que pour un instantané versionné compatible, avec validation physique ; sinon
repartir de l'état initial déclaré et informer l'utilisateur.

Exporter les circuits mixtes dans le nouveau format ; refuser explicitement
un export ancien qui supprimerait l'air ou les liens. Import/export aller-retour,
annuler/rétablir, duplication, suppression et changement de vue préservent les
identités et évitent les liens orphelins.

Un drapeau expérimental désactivé par défaut permet la qualification progressive.
Quand il est désactivé, les projets électriques suivent leur chemin existant ;
un projet mixte reste identifiable et ne se transforme pas silencieusement en
projet électrique incomplet. La désactivation ne détruit aucune donnée.

## 9. Lots et jalons du programme

Un lot ne commence qu'avec ses prérequis qualifiés et son plan détaillé. Chaque
lot produit une PR limitée et un rapport de qualification. La table représente
des dépendances, pas une durée garantie.

| Lot | Livrable | Prérequis | Critère de sortie |
|---|---|---|---|
| R0 — Référence | Base candidate identifiée, inventaire, tests de référence, budgets et scénarios gelés | Revue du document | SHA et rapports reproductibles ; aucune régression préexistante dissimulée |
| R1 — Contrats | Domaine pneumatique, enveloppe de projet, ports, liens et migration | R0 | Anciens projets et contrats électriques préservés ; connexions invalides refusées |
| R2 — Physique indépendante | Réseau d'air, distributeurs manuels, vérins et instruments numériques | R1 | Cas analytiques, bilans et convergence réussis sans interface |
| R3 — Couplage | Bobines 24 V CC et capteurs liés au mouvement | R2 | Séquence complète calculée et absence de double intégration du temps |
| R4 — Atelier | Palette, platine, schéma, tuyaux, courbes et animations | R1–R3 | Parcours utilisateur complet, deux vues cohérentes, preuves réelles |
| R5 — Extension réaliste | Réservoir, traitement d'air non idéal, défauts et nouveaux appareils | R4 | Fiches physiques et tests propres à chaque famille |
| R6 — Qualification | Performances, builds cibles, artefacts et rapport de livraison | R4 ; R5 pour les extensions livrées | Tous les critères de la livraison passent sur son SHA |

Catalogue R2 : alimentation régulée idéale, distributeur 3/2 monostable,
distributeur 5/2 manuel, vérin simple effet, vérin double effet, restriction
unidirectionnelle réglable, clapet, jonction en T, échappement/silencieux simple
et manomètre. R3 ajoute 5/2 à une bobine/rappel, 5/2 à deux bobines bistable,
capteur de position à contact et pressostat. Aucun 5/3 n'est ajouté sans table
des trois positions et qualification des pressions emprisonnées.

## 10. Matrice de preuve et critères de qualification

Les seuils ci-dessous sont des critères initiaux à vérifier. Toute modification
d'un seuil exige une décision motivée avant le résultat final, jamais un
assouplissement après un échec pour rendre le tableau vert.

| ID | Cas | Preuve et résultat exigés |
|---|---|---|
| PHY-01 | Force du vérin 32 mm à 6 bar relatifs | 482,55 N à ±0,5 N, sans frottements ; rentrée réduite selon la tige |
| PHY-02 | Volume isolé | Masse conservée, pression stable à température/volume fixes ; dérive relative ≤ 10⁻⁶ sur 10 s |
| PHY-03 | Réseau avec source/échappement | Bilan intégré masse stockée/entrante/sortante : erreur relative ≤ 0,1 %, avec normalisation documentée pour petits flux |
| PHY-04 | Passage compressible | Débit nul à pressions égales, inversion de signe, plateau sonique conforme à une référence indépendante |
| PHY-05 | Restriction/clapet | Sens libre/restreint vérifiés ; contre-sens du clapet bloqué selon son modèle |
| PHY-06 | Mouvement sous charge | Accélération, arrêt par charge, rentrée/sortie et butées conformes aux équations déclarées |
| PHY-07 | Convergence temporelle | Réduire la tolérance ou diviser le pas limite par deux modifie la pression/position normalisée de ≤ 1 % ; pas de commutation perdue |
| CPL-01 | Bouton → bobine → 5/2 → vérin → capteur → retour | Courbes et journal d'événements montrent la chaîne calculée et son ordre causal |
| CPL-02 | Coupure bobine et coupure air | Monostable/bistable distincts ; pression piégée préservée lorsqu'elle doit l'être |
| CPL-03 | Seuils et commandes opposées | Hystérésis, délais et règle explicite ; pas de vibration infinie des états |
| CPL-04 | Événement à temps nul | Aucun double comptage mécanique, massique ou électrique |
| REG-01 | Projet électrique sans pneumatique | Références DC/AC1/AC3/PV et mesures/protections existantes toujours correctes |
| REG-02 | Anciens fichiers | Migration v0/v1/v2 sans perte ; entrée inconnue refusée sans écrasement |
| REG-03 | Deux vues et historique | Identités, paramètres et connexions identiques après édition, annulation et sauvegarde |
| ERR-01 | Données non finies, dimensions nulles ou pression inadmissible | Refus ou diagnostic explicite avant affichage trompeur ; aucune fuite de NaN/infini |
| ERR-02 | Non-convergence/worker arrêté | Dernier état accepté identifié, temps cohérent, diagnostic et interface réactive |
| UI-01 | Montage depuis la palette | Raccords cliquables, tuyaux corrects, sélection et inspecteur fonctionnels |
| UI-02 | Pièces mobiles et mesures | Tige/tiroir animés selon résultats, corps et raccords fixes ; pression distinguée du débit |
| PERF-01 | 30/100/200/400 composants | Mesures comparables en release, pas seulement nombre de widgets affichés |
| BUILD-01 | Plateformes cibles | Build et lancement réel Web/Mac Intel au minimum ; autres plateformes seulement si qualifiées |

R2-A fixe les normalisations numériques, références indépendantes et tolérances
absolues complémentaires avant l'implémentation qualifiée. Les bilans de masse
incluent sources et échappements ; un test de conservation dans un système
ouvert n'exige pas une masse totale constante.

La matrice de régression inclut notamment : rails DIN, platine métallisée,
alignement des vis/ports, routage, instruments, protections, contacts liés,
moteurs CC, triphasé, son des avertisseurs et persistance. Une modification
des images de référence doit être justifiée visuellement, jamais exécutée
automatiquement pour faire disparaître un échec.

## 11. Performance : méthode et budgets

R0 publie les configurations de référence : OS, navigateur, CPU, mémoire,
résolution, fréquence écran, mode release et versions des outils. Une machine
disponible peut servir de référence provisoire, mais son résultat ne devient
pas une promesse pour tous les appareils.

Pour chaque taille 30/100/200/400, mesurer trois scénarios : électrique seul,
pneumatique active et montage mixte. Le manifeste indique séparément appareils,
ports, tuyaux, volumes, vérins en mouvement et fréquence de commutation.
Les tailles élevées comprennent plusieurs sous-circuits actifs, pas seulement
des composants décoratifs déconnectés. Tous les montages doivent être physiquement
valides et avoir un état attendu.

Après échauffement de 10 s, mesurer 60 s, répéter trois fois et conserver les
données brutes. Publier médiane, p95 et maximum pour clic de connexion, calcul,
publication des résultats et frame UI. Relever la mémoire stabilisée et ses
tendances après ouvertures/fermetures répétées.

Budgets initiaux sur la configuration de référence :

- Clic de connexion : retour visuel p95 ≤ 100 ms ; calcul ultérieur sans blocage.
- Interface : objectif 60 Hz ; au moins 95 % des frames ≤ 16,7 ms après échauffement.
- Temps simulé : suivre le temps réel pendant 60 s avec retard accumulé ≤ 100 ms,
  sans supprimer de sous-pas nécessaires ni de commutations.
- Calcul : traiter 100 ms simulées en p95 ≤ 80 ms sur le scénario de 400 composants,
  hors thread graphique, avec les tolérances scientifiques maintenues.
- Électrique seul : dégradation p95 ≤ 10 % par rapport à R0, avec dispersion
  des trois répétitions publiée ; un dépassement reproductible bloque la livraison.
- Ressources : aucune file de requêtes non bornée, aucun worker/lecteur/timer
  restant actif après fermeture ; absence de croissance persistante des objets
  retenus vérifiée par profil, pas seulement par le RSS du processus.

Un budget non atteint entraîne optimisation ou limitation de périmètre annoncée.
Il est interdit de réduire silencieusement la fidélité physique pour afficher
« 400 composants sans ralentissement ». La taille de maillage 3D et les textures
sont également mesurées, car elles peuvent limiter le rendu indépendamment du solveur.

## 12. Gouvernance autonome et gestion des branches

### 12.1 Ce que l'exécutant peut décider et accomplir

Dans un lot dont le plan a été validé : choix internes compatibles avec les
contrats, corrections, tests, documentation, références publiques, modèles
génériques déclarés, optimisation sans réduction des exigences, commits et PR
de revue. Pas de nouvelle demande d'autorisation pour chaque action réversible.
Cette règle ne constitue pas une autorisation de fusionner ou de publier une release.

Sans inventer d'informations, une incertitude de donnée fabricant peut être
résolue par un modèle générique identifié et documenté. Une incertitude de loi
physique, de format de stockage ou de comportement causal doit être traitée
par référence, essai indépendant ou décision architecturale avant développement.

### 12.2 Conditions de suspension du travail dépendant

Suspendre seulement les tâches concernées si : base active impossible à
identifier, conflit touchant le même contrat avec une branche parallèle,
régression non expliquée, référence physique contradictoire, non-convergence,
migration destructive, données fabricant non licenciables ou extension de périmètre.
Continuer les travaux indépendants autorisés. Rapporter le constat, les preuves,
les options et la décision requise ; ne pas contourner un échec par un faux état.

### 12.3 Règles Git

R0 relève les branches candidates avec leurs SHA et modifications pertinentes.
La date la plus récente n'est pas un critère suffisant pour choisir une base.
Retenir une base qualifiée et documenter ses dépendances aux PR ouvertes.
Créer une branche pneumatique isolée depuis cette base, puis une branche par lot.
Ne pas modifier la branche de travail de l'utilisateur ni forcer son historique.

Avant intégration : comparer la base courante, traiter les conflits sémantiques,
rejouer les contrats, la régression électrique et les parcours mixtes sur le
commit résultant. Un rebase ou merge rend obsolète la qualification précédente.
Ne jamais associer une preuve d'une branche de démonstration à une autre version.
Fusion et publication de release restent soumises à instruction explicite de
l'utilisateur, conformément au choix de fusion différée dans la session.

## 13. Cycle obligatoire d'un lot

1. Lire ce document, le registre de décisions, le rapport précédent et les
   instructions locales ; vérifier branche, SHA, état du worktree et prérequis.
2. Rédiger le plan du lot : fichiers exacts, interfaces consommées/produites,
   hypothèses, tests, risques, preuves et procédure de retour arrière.
3. Valider les décisions architecturales du lot avant de changer les contrats
   partagés ; les détails d'implémentation restent autonomes.
4. Pour un nouveau comportement physique ou une correction significative,
   établir un test indépendant montrant l'erreur avant la correction.
5. Implémenter par changements limités ; vérifier dès qu'un contrat est touché.
6. Contrôler le diff : moteur/UI séparés, unités, identité, migration, ressources,
   état temporel et cohérence des sorties.
7. Exécuter les vérifications pertinentes une fois sur le commit final ; ajouter
   la suite complète aux jalons transversaux et avant livraison. Ne pas multiplier
   les exécutions identiques en l'absence de changement ou de nouvelle incertitude.
8. Produire les preuves, le rapport et une PR dont le titre décrit l'état final.
9. Faire une revue critique de la branche entière avant fusion. Une relecture
   indépendante est souhaitable ; si elle n'a pas eu lieu, l'indiquer explicitement.
   L'autonomie ne présume pas l'autorisation de lancer des agents supplémentaires.
10. Marquer le lot qualifié seulement si tous ses critères passent ; sinon
    conserver le statut bloqué ou partiel et lister les écarts.

Commandes existantes à réutiliser selon les fichiers touchés :

```bash
# Depuis apps/electrosim, après restauration des dépendances :
flutter analyze
flutter test --no-pub --concurrency=1

# Depuis packages/electrosim_canvas lorsque le Canvas est touché :
flutter test --no-pub --concurrency=1

# Depuis la racine :
python3 tools/core_unify_architecture_guard.py
python3 tools/postv2_p1_contract.py
git diff --check
```

Ajouter les tests des nouveaux packages et ceux du stockage lorsqu'ils sont
touchés. Les commandes détaillées et dépendances nécessaires sont figées dans
chaque plan ; une suite app verte ne couvre pas automatiquement tous les packages.
Un simple build d'entrée de démonstration ne remplace pas celui de l'entrée
de production `lib/main.dart` à la livraison.

Les workflows existants ont des filtres de branches : créer ou adapter une
qualification pneumatique explicite. Aucun succès CI ne doit être supposé
sur une nouvelle branche sans vérifier que les jobs ont effectivement démarré.
La CI de qualification contrôle les formats et goldens sans les réécrire ni
committer automatiquement des fichiers de preuve dans la branche examinée.

## 14. Preuves, traçabilité et communication

Conserver dans `docs/pneumatics/qualification/<lot>/` un manifeste et un rapport.
Les artefacts lourds peuvent rester en pièces jointes CI avec URL, SHA et empreinte.
Le rapport contient obligatoirement :

- lot, statut, base, SHA qualifié, versions des modèles et changements livrés ;
- exigences couvertes et écarts ; fichier/scénario qui prouve chaque exigence ;
- commandes exactes, environnement, résultat, date et liens des journaux ;
- valeurs analytiques attendues, résultats mesurés et tolérances ;
- captures du vrai produit, vidéo/GIF, courbes et journal d'événements ;
- benchmarks bruts et synthèse, comparaison à R0 ;
- plateformes réellement compilées et réellement lancées, distinguées ;
- limitations et défauts ouverts, régressions éventuelles et marche arrière ;
- prochaine action et condition d'entrée du lot suivant.

Statuts autorisés : non commencé, en cours, bloqué, implémenté non qualifié,
qualifié, intégré. « Intégré » exige présence du changement sur la branche
cible ; « qualifié » exige les preuves. Une capture de rendu, un test unitaire
ou une compilation isolée ne remplit pas à elle seule ces deux statuts.

La progression se rapporte par lots et critères : « R2 : PHY-01 à PHY-05
réussis, PHY-06/07 ouverts », plutôt qu'un pourcentage subjectif. À chaque
reprise, relire le manifeste ; ne pas recommencer un travail déjà qualifié et
ne pas présenter une intention comme une modification réalisée.

## 15. Décisions et registre de pilotage

Chaque décision est conservée dans `docs/pneumatics/decisions/` avec contexte,
options, choix, conséquences, auteur/date et critères de réexamen. Les
décisions initiales de ce document sont :

| ID | Décision | Justification |
|---|---|---|
| ADR-P01 | Modèle physique concentré compressible | Réalisme utile sans CFD |
| ADR-P02 | Réseau pneumatique séparé du graphe électrique | Préserver pertes, volume et compatibilité |
| ADR-P03 | Enveloppe multiphysique, `CircuitState` v1 conservé initialement | Migration maîtrisée et moindre régression |
| ADR-P04 | Couplage explicite bobines/capteurs | Causalité et identité testables |
| ADR-P05 | Sous-pas et événements indépendants des images | Exactitude temporelle et fluidité |
| ADR-P06 | Thermique isotherme déclaré pour R2 | Périmètre scientifique borné |
| ADR-P07 | Pilote électropneumatique 24 V CC | Qualification complète avant élargissement |
| ADR-P08 | Platine et schéma : deux dispositions, un modèle | Lisibilité sans duplication physique |

Créer avant exécution `docs/pneumatics/PROGRAM_STATUS.md` avec la table R0–R6,
le SHA de base, les branches/PR, les preuves, les décisions ouvertes et les
limitations. État initial : aucun lot pneumatique implémenté. Toute modification
de ce document directeur change sa version et explique les exigences modifiées.

## 16. Recette de référence et livraison

Recette minimale : depuis un projet vide, ajouter une alimentation d'air, un
5/2 monostable à bobine 24 V, un vérin double effet, une restriction de débit,
un bouton électrique, les contacts nécessaires et un capteur de fin de course.
Raccorder dans la platine, vérifier le même montage dans le schéma, lancer,
observer la sortie puis le retour commandé par le capteur. Faire varier la
restriction et la charge ; vérifier les vitesses et un éventuel arrêt sous charge.

La commande de référence utilise un relais K1 et son contact NO de maintien.
Le bouton de départ S1 NO est en parallèle avec K1 NO ; ce groupe est en série
avec le contact B1 NC de fin de sortie et alimente la bobine K1. La bobine Y1
du 5/2 reçoit la même commande. Une impulsion S1, relâchée avant l'arrivée
en fin de course, maintient K1/Y1 jusqu'à l'ouverture de B1, puis le ressort
du distributeur commande le retour. La fermeture de B1 pendant le retour
ne réenclenche pas K1 puisque S1 et K1 NO sont ouverts.

Un S1 maintenu peut provoquer une répétition : la recette ne doit pas faire
passer cette commande pour un cycle unique garanti. L'anti-répétition est une
fonction de commande distincte à qualifier si elle est ajoutée. Le plan R3
inclut le schéma exact, la durée d'impulsion compatible avec le scénario et
les chronologies des essais S1 relâché et S1 maintenu.

Puis tester pause/reprise, coupure 24 V, fermeture d'air, sauvegarde/réouverture
et annuler/rétablir. Vérifier pression résiduelle, état du distributeur et
contacts ; aucun état initial ambigu n'est accepté.

Une livraison est recevable lorsque : tous les critères du périmètre livré
passent, les projets électriques existants restent utilisables, la recette
est reproductible dans le vrai produit, les budgets annoncés sont mesurés,
les builds cibles sont disponibles et les limitations sont publiées.

Le retour arrière restaure le code précédent ou désactive l'extension ; il
préserve les nouveaux fichiers de projet et leurs originaux. L'ancienne version
ne doit jamais ouvrir puis réenregistrer un projet mixte en perdant ses données.
La livraison finale n'est pas annoncée avant qualification du commit intégré.
