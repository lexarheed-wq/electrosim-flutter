# Atelier mixte CC / AC / AC3 / photovoltaïque

État : proposition d'architecture à revoir, **pas une fonction déjà intégrée**.
Demandes retenues : appareils sur une même platine ; solaire et batterie
prioritaires, réseau en secours ; conservation des projets et modes existants.

## Ce qui change réellement

La platine est une vue commune. Elle ne détermine pas la loi électrique.
Aujourd'hui `CircuitState.mode` sélectionne un solveur global et les contrats
refusent les appareils incompatibles avec ce mode. Masquer ces refus ou ajouter
un libellé « mixte » laisserait des calculs incorrects.

Le futur moteur `MixedWorkshopRuntime` doit construire des réseaux électriques
cohérents, adapter les appareils qui relient ces réseaux, puis publier un seul
instantané atomique pour la platine, les mesures et les animations. Les moteurs
actuels restent utilisables pour les projets classiques.

## Domaine électrique et îlot

Un domaine est CC ou AC, avec fréquence et référence électrique pour l'AC. AC1
et AC3 sont des configurations de phases ; un récepteur L/N peut fonctionner
entre une phase et le neutre d'un réseau triphasé si son contrat le permet.
Une tension nominale est une caractéristique d'appareil, pas une autorisation
pour fusionner arbitrairement deux réseaux.

Un îlot est une partie conductrice connexe calculable avec un même solveur. Les
bornes de puissance, bobines, contacts et électronique de commande d'un même
appareil peuvent appartenir à des îlots distincts. La liaison mécanique d'un
contacteur transmet son état, jamais une tension entre bobine et contacts.
La terre et les défauts d'isolement doivent être traités explicitement : PE,
neutre et retour CC ne sont pas automatiquement le même conducteur.

Chaque îlot reçoit une identité stable, une version de topologie, une liste de
bornes et son modèle de calcul. Les identifiants d'appareils, de bornes et de
connexions du projet sont conservés. Les sous-modèles de calcul sont des
projections de runtime, avec correspondance vers leurs appareils auteurs.

## Appareils qui relient les réseaux

| Appareil | Liaison calculée | Exigence |
|---|---|---|
| Alimentation AC/CC | Entrée AC, sortie CC | Puissance d'entrée liée à la charge et au rendement ; limite de courant |
| Redresseur | AC vers CC | Modèle annoncé : moyenne ou transitoire ; ne pas inventer une ondulation |
| Convertisseur CC/CC | Deux niveaux CC | Rendement, limites, isolation annoncée |
| Onduleur | CC vers AC | Puissance disponible, fréquence, tension, limitations |
| Variateur | AC/CC interne vers AC moteur | Fréquence de sortie et moteur compatibles ; modèle réduit documenté |
| Transformateur | Deux réseaux AC | Rapport, puissance et isolation ; fréquence commune |
| Contacteur | Commande et contacts de puissance | Couplage d'état sans liaison conductrice implicite |
| Inverseur de sources | Deux entrées vers une sortie | Interverrouillage et ouverture avant fermeture |

Une source PV ne devient pas une alimentation idéale de tension fixe par un
simple dessin. L'adaptateur PV doit utiliser une loi I(V)/P(V) cohérente avec
les paramètres disponibles. Le moteur PV actuel, qui représente une chaîne
fonctionnelle autonome, doit rester conservé jusqu'à qualification de son
adaptateur CC. Une source absente rend un îlot hors tension ; ce cas est distinct
d'une matrice singulière ou d'un câblage invalide.

## Résolution couplée

1. Valider les bornes, domaines et compatibilités de sources.
2. Construire ou réutiliser les topologies d'îlots affectés.
3. Appliquer les états mécaniques et protections au début du pas.
4. Résoudre les réseaux et échanger les puissances via les convertisseurs.
5. Itérer avec tolérances et nombre maximal d'itérations documentés.
6. Après convergence, avancer **une seule fois** batteries, thermique,
   mécanique et compteurs avec le temps simulé du pas.
7. Publier ensemble les résultats, états, diagnostics et valeurs disponibles.

Les itérations électriques internes ne doivent pas cumuler plusieurs fois les
kWh ou le SOC. En cas de non-convergence, l'interface signale le résultat
indisponible ; elle ne conserve pas silencieusement une fausse valeur. Un défaut
dans un îlot indépendant ne doit pas arrêter tous les autres. Une modification
de circuit invalide les calculs en cours portant une ancienne version.

## Alimentation hybride retenue

Première version recommandée : onduleur autonome avec batterie et inverseur
vers le réseau. Ce périmètre permet un véritable secours sans prétendre à une
injection réseau synchronisée.

Priorité : PV, puis batterie au-dessus de son seuil de réserve, puis réseau.
Le SOC possède deux seuils distincts pour départ et retour ; disponibilité,
qualité de tension et stabilité du solaire sont temporisées. L'inverseur ouvre
la source sortante, attend son délai, vérifie l'ouverture, puis ferme l'autre.
Les commandes contradictoires sont refusées et l'état indéterminé ouvre les
contacts. Les charges peuvent réellement subir une coupure pendant le transfert.

Une seconde version pourra intégrer un onduleur raccordé au réseau, avec
synchronisation, limites d'injection, anti-îlotage et bilan d'énergie. Une
alimentation réseau en secours ne signifie pas automatiquement que ces fonctions
sont présentes.

Les compteurs mesureront le flux **à leurs bornes**. Dans le lot actuel, le
compteur PV mesure la sortie AC de l'onduleur autonome ; E+ et E− sont les deux
orientations du compteur, pas un bilan réseau import/export déjà simulé.

## Interface et persistance

Ajouter un espace Atelier mixte opt-in, sans convertir automatiquement les
projets classiques. Montrer le domaine et la tension près des bornes lors du
raccordement, ainsi que les causes d'un refus. Les blocs de conversion et le
chemin actif du secours doivent rester compréhensibles sur la platine comme sur
le schéma. Une indisponibilité de mesure s'affiche « — », jamais un nombre inventé.

Le format de sauvegarde doit être versionné pour les domaines, paramètres des
convertisseurs, états persistants et index d'énergie. Une migration idempotente
préserve positions, tailles personnalisées, routages, identifiants et mode
historique. Les sauvegardes d'anciennes versions restent lisibles.

## Déploiement par étapes

1. Inventorier les contrats et figer des circuits de référence classiques.
2. Ajouter la description des domaines et leur validation, sans modifier les
   résultats historiques.
3. Calculer deux îlots indépendants CC/AC sur une platine commune.
4. Ajouter une alimentation AC/CC puis une commande CC de contacteur AC3.
5. Intégrer les adaptateurs PV, batterie et onduleur avec bilan de puissance.
6. Ajouter l'inverseur de secours et sa machine d'états.
7. Qualifier compteurs, protections, défauts, sauvegardes et interface.
8. Étudier ensuite le raccordement réseau synchronisé.

## Tests et critères de qualification

- Résultats classiques identiques avant/après, avec tolérances publiées.
- Alimentation 230 V / 24 V, commande 24 V et moteur triphasé indépendants.
- Conservation de puissance et pertes des convertisseurs, limites et panne.
- Pas de fermeture simultanée de l'inverseur ; coupure et retour temporisés.
- Réserve batterie, hystérésis, variation d'irradiance et disparition du réseau.
- Énergie intégrée une fois par pas, signes corrects et index sauvegardés.
- Sources incompatibles, neutre manquant, erreur de phase, PE et isolement.
- Ajout/suppression pendant un calcul, annulation, import d'ancien projet.
- Campagne de 30, 100 et 400 appareils avec nombre d'îlots et convertisseurs
  explicités : latence de connexion, temps de résolution, images par seconde,
  mémoire, coût des échanges et nombre d'itérations.

L'objectif de 400 appareils doit être mesuré ; il ne découle pas du découpage.
Les optimisations prévues sont les îlots invalidés seulement quand nécessaire,
les caches bornés de topologie, les facteurs de matrice réutilisables et des
repaints limités aux états effectivement modifiés.
