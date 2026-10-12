# Signes de fonctionnement des appareils — exigence validée

L'utilisateur demande des effets réalistes sur tous les appareils pour rendre
leur fonctionnement lisible. Cette exigence complète le chantier 3D.
Ce document définit le travail à intégrer ; il ne certifie pas son exécution.
Les commandes dessinées peuvent rester inactives tant que leur utilité n'a
pas été démontrée.

## État électrique avant effet graphique

Le rendu consomme le dernier résultat validé du moteur de simulation.
Il ne modifie pas le circuit. Distinguer simulation arrêtée, alimentation
disponible, appareil en fonctionnement, défaut et valeur indisponible.
Une tension aux bornes ne prouve pas à elle seule un fonctionnement : il faut
considérer courant, puissance active, commandes et état du modèle concerné.
Les seuils et l'hystérésis doivent être définis par famille, avec les unités
correctes et sans transformer le bruit numérique en clignotements.

En cas de disjonction, débranchement, circuit ouvert ou perte de phase,
le retour visuel doit suivre la réponse réelle du modèle. Une décélération
ou un refroidissement persistent seulement si une dynamique correspondante
est calculée ; sinon l'état de fonctionnement s'arrête sans fausse inertie.

## Retours par famille

| Famille | Retour adapté | Condition et limite |
| --- | --- | --- |
| Moteurs et ventilateurs | Rotation complète de l'arbre/des pales accessibles | Vitesse et sens issus du modèle ; préserver les rotations existantes |
| Broyeur | Retour de fonctionnement discret dans l'interface ; son mécanique facultatif | Aucun volant manuel ni capot ne tourne ; ne pas rendre les organes internes visibles artificiellement |
| Convoyeur | Défilement de la bande et rotation de ses rouleaux | Sens/vitesse du moteur ; aucun transport de matériau fictif |
| Mixeur | Rotation de l'organe accessible, bruit facultatif | Dépendre de l'entraînement réel et du mode choisi |
| Pompes | Retour de moteur actif ; flux uniquement avec un modèle de débit | L'alimentation électrique ne démontre ni débit ni pression |
| Compresseur | Retour de moteur actif et son facultatif | Le manomètre n'affiche une pression que si celle-ci est calculée |
| Réfrigérateur/congélateur | Retour discret du compresseur actif | Aucun refroidissement ni cycle de thermostat inventé |
| Climatiseur | Mouvement des pales visibles ; retour discret du compresseur | Flux d'air/température seulement avec un modèle correspondant |
| Fer et charges chauffantes | Retour de chauffe discret, ou température calculée dans les mesures | Ne pas faire rougir un fer ménager ; pas de vapeur sans modèle adapté |
| Ordinateur/téléviseur | Voyant ou écran actif si conforme au rendu de référence | Distinguer veille et fonctionnement quand le modèle le permet |
| Lampe/LED | Émission lumineuse localisée | Polarité, tension/courant et défauts ; émission coupée si non fonctionnelle |
| Buzzer/claxon | Son adapté et retour visuel discret | Commande électrique réelle ; un seul son par événement/état, volume réglable |
| Instruments | Affichage de mesures et états OFF/HOLD/erreur | Garder les contrats électriques des instruments déjà qualifiés |
| Sources et charges passives | Indication discrète de fourniture/consommation et flux dans les fils | Pas de mouvement, luminescence ou son inexistant sur l'objet réel |

Les retours d'interface sont séparés du modèle photographique : ne pas ajouter
de voyant matériel fictif à un équipement qui n'en possède pas. Leur présence
ne réintroduit pas les noms de composants retirés de la platine.

## Fluidité et validation

- Utiliser une horloge d'animation partagée, pas un Timer par appareil.
- Mettre les couches animées dans des RepaintBoundary distinctes ; conserver
  les textures Cycles et la platine en couches statiques.
- Suspendre les effets hors écran et les effets continus à l'arrêt ; respecter
  la réduction des animations et permettre de couper les sons.
- Les sons restent facultatifs : aucune activation automatique bruyante au
  chargement d'un projet ; gérer les restrictions audio du navigateur.
- Vérifier chaque famille sous tension, en circuit ouvert, débranchée,
  après protection déclenchée et lors des changements de paramètres.
- Pour les pièces tournantes : vérifier sens, tour complet et variation de
  vitesse, sans confondre la vitesse d'une boucle graphique avec une mesure.
- Mesurer les performances avec 30 puis 400 composants représentatifs avant
  de revendiquer la fluidité ; un benchmark de rendu seul ne qualifie pas le
  coût du solveur ou de la connexion des fils.

Les preuves de chaque composant devront distinguer : texture statique,
capture réelle dans ElectroSim, et effet de fonctionnement réellement testé.
