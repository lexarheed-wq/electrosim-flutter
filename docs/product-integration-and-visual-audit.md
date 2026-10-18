# ElectroSim — intégration des ateliers et audit des composants visuels

Date de l’audit : 2026-10-18
Base inspectée : branche `codex/mixed-control-power-regression` (candidat de la PR 144).

## Intégration des versions

Le candidat inspecté contient déjà dans la même application Flutter les ateliers
électriques, mixtes et pneumatiques, ainsi que leurs packages de domaine et leurs
solveurs. La différence visible venait du fait que l’accès pneumatique était
masqué par défaut derrière `ELECTROSIM_PNEUMATICS_EXPERIMENTAL`. Cette porte
compile-time est retirée du routage du centre de conception : l’atelier est
maintenant ouvrable depuis le même ElectroSim que les modes électriques.

Les deux domaines ne doivent pas être confondus dans le moteur : la pneumatique
conserve ses appareils, pressions et connexions propres, tandis que le mode mixte
électrique distingue les réseaux CC, AC, AC3 et photovoltaïques. L’atelier
pneumatique reste identifié comme bêta et annonce clairement les limites du
solveur et l’absence actuelle d’exécution complète des circuits mixtes
électropneumatiques.

L’ancienne branche pneumatique `feat/pneumatics-r6lmn-staging-20261011` a une
racine Git distincte et ne peut pas être fusionnée comme une branche ordinaire.
Son arbre contient des différences importantes avec la branche candidate. Il
faut porter les fonctionnalités R6L/M/N utiles au cas par cas, après comparaison
des contrats et migrations, sans remplacer en bloc le candidat électrique/mixte.

## Règle de classement des visuels

Un composant est « photo/3D disponible » uniquement si une image de produit est
effectivement fournie pour la palette (`*-palette.png`) et la platine
(`*-front.png`). La présence d’un `CustomPainter`, d’un renderer Dart, d’une
géométrie JSON ou d’une entrée dans `coveredModelTypes` indique seulement qu’un
composant est dessiné ; elle ne constitue pas une preuve de rendu 3D.

### Composants avec assets 3D à deux vues

Le registre `F18PhysicalPlateAssets.models` référence des images Cycles front et
palette pour les familles industrielles courantes. Des familles hors de ce
registre ont également leurs chargeurs spécialisés : instruments portatifs,
compteurs d’énergie, sources AC3, charges triphasées, prises et appareils
catalogue. Elles sont comptées selon leurs assets et leurs vues réelles, et non
selon les seules clés du registre commun.

### Lacunes visuelles identifiées

| Famille / types | Vue palette actuelle | Vue platine actuelle | Écart à la cible |
| --- | --- | --- | --- |
| Temporisateur `timer_star_delta` | Image Cycles trois-quarts quand le lot Blender est généré, dessin Dart de secours | Image Cycles frontale avec voyants d’état dynamiques, dessin Dart de secours | Script et chargement intégrés; images Cycles en attente de génération dans l’environnement Blender natif |
| Automates `plc_ac3`, `plc_dc` | Image Cycles trois-quarts quand le lot Blender est généré, dessin Dart de secours | Image Cycles frontale avec voyants d’état dynamiques, dessin Dart de secours | Script et chargement intégrés; images Cycles en attente de génération dans l’environnement Blender natif |
| Verrouillage mécanique `mechanical_interlock_ac3` | Image Cycles trois-quarts quand le lot Blender est généré, dessin Dart de secours | Image Cycles frontale, dessin Dart de secours | Script et chargement intégrés; images Cycles en attente de génération dans l’environnement Blender natif |
| Instruments portatifs : voltmètre, ampèremètre, fréquencemètre et testeur d’ordre des phases | Images Cycles dédiées chargées par registres spécialisés | Images Cycles dédiées avec lectures superposées par Flutter | Couverture confirmée : 8 images pour 4 instruments |
| Compteurs : `energy_meter_ac1`, `energy_meter_ac3` et variante PV | Images Cycles via le catalogue d’appareils natifs | Images Cycles frontales avec lectures d’énergie superposées | Couverture confirmée : 9 images pour 3 compteurs, vues palette, front et accès service |
| Capteurs : `proximity_sensor_24v`, `limit_switch_no`, `limit_switch_nc` | Image Cycles dédiée quand le lot Blender est généré | Image Cycles frontale; variantes actionnées générées pour LED et levier | Script, chargement des images et repli Dart intégrés; fichiers Cycles à générer dans l’environnement Blender natif |
| Sources et charges spéciales : `ac3_voltage_source`, `pv_resistive_load`, `load_wye_3p`, `load_delta_3p`, `power_socket_ac`, `power_socket_dc` | Images Cycles par registres spécialisés | Images Cycles frontales | Couverture confirmée pour les modèles ayant des assets dans `g5_industrial/` |
| Différentiel `rcd_2p_ac1` | Renderer 3D Dart dédié | Renderer 3D Dart dédié | Forme et commandes présentes; pas encore d’image produit Cycles |
| Pneumatique : source, régulateur, distributeurs 3/2 et 5/2, clapet, régleur, vérins simple/double effet, té, collecteur, silencieux, manomètre, pressostat, capteur de position et autre | Image Cycles trois-quarts dédiée | Image Cycles de face dédiée | 15 modèles, 30 images générées et raccordées à la palette et à la platine ; les symboles de schéma restent vectoriels |
| Appareils catalogue génériques (batterie, générateur, chauffage générique, actionneur, capteur, indicateur) | rendu catalogue Dart avec détails selon la variante | rendu catalogue Dart | Pas encore d’images Cycles; plusieurs appareils ménagers et moteurs ont des images natives dédiées |

Le banc électropneumatique d’apprentissage est aussi illustré par des symboles
et des éléments peints. Il n’est pas couvert par les images des 15 appareils de
l’atelier : son inventaire visuel doit être réalisé avec son propre ensemble de
composants et leurs variantes.

## Plan d’exécution visuelle

1. Constituer un registre canonique des IDs de composants de chaque catalogue,
   avec pour chaque ID les rendus palette, platine, schéma, états et provenance.
2. Prioriser les modules de commande et les capteurs qui n’ont pas encore
   d’images Cycles, puis compléter les appareils catalogue génériques.
3. Créer des modèles 3D originaux cohérents (Cycles) et produire deux rendus par
   appareil : trois-quarts palette et frontal platine. Les images de référence
   servent à définir la forme et les marquages, pas à masquer les composants par
   de simples photos sans adaptation aux bornes interactives.
4. Conserver les bornes et états actifs dans la couche Dart, caler chaque image
   sur les ancres électriques/pneumatiques, puis remplacer les glyphes uniquement
   dans les vues physiques ; conserver les symboles normalisés en vue schéma.
5. Compléter chaque famille jusqu’à ce qu’aucun composant catalogue n’utilise un
   placeholder ou un glyph physique. Le test visuel et le contrôle sur platine
   restent requis avant livraison de chaque lot.

## Lot pneumatique livré localement

Blender 4.5.14 LTS a été installé sur le Mac Intel. Le moteur de rendu a été
lancé depuis le Terminal macOS de l’utilisateur : 30 PNG ont été générés dans
`apps/electrosim/assets/g5_pneumatic/`. Le widget `PneumaticDeviceGlyph` utilise
la vue trois-quarts dans la palette, la vue frontale sur la platine et conserve
le dessin vectoriel en schéma. Les images sont des modèles procéduraux Cycles,
pas des photos de marque ni une certification de fidélité dimensionnelle.

Le processus headless depuis l’environnement Codex s’arrête au démarrage dans
la détection Metal du GPU. Le script source reste dans
`tools/render_pneumatic_components.py` pour les générations/reprises depuis un
Terminal macOS où Blender peut accéder au GPU.

Le générateur de commande produit les images une fois exécuté sous Blender. Le
lot de catalogue générique et l’inventaire indépendant du banc électropneumatique
restent des travaux ultérieurs.

## Raccordement Blender du lot commande

Le script `tools/render_control_components.py` construit des maillages génériques
originaux pour le temporisateur étoile-triangle, les automates AC3/CC, le verrou,
le capteur inductif et les fins de course NO/NC. Il prépare la vue palette et la
vue frontale, plus une variante actionnée des capteurs. Les widgets de la palette
et de la platine chargent ces fichiers depuis `assets/g5_control/`; les voyants
PLC et temporisateur restent pilotés par les états de simulation et les visuels
Dart demeurent disponibles si le lot d’images est absent ou incomplet.
Les rendus ne commandent jamais les contacts ni les sorties : le temporisateur
lit l’alimentation de sa bobine et sa temporisation pour commuter étoile puis
triangle après le temps mort; l’automate interprète son programme Ladder et ses
entrées câblées; les capteurs font évoluer leur contact selon l’état actionné.
Les images de capteurs comportent une variante de repos et une variante active,
le curseur du timer suit le délai configuré, les voyants PLC suivent Q0–Q3 et
l’alimentation/erreur, et la position du verrou suit le contacteur A ou B actif.

Les références ont servi à comparer l’encombrement et les détails visibles :
[temporisateur étoile-triangle Schneider RE22](https://www.se.com/ca/en/product/LAD93217/kit-for-star-delta-starter-assembly-of-for-2-x-contactors-lc1d25d38-and-star-lc1d09d18-with-timer-block/),
[automate Siemens S7-1200](https://sieportal.siemens.com/en-ww/products-services/detail/6ES7214-1AF50-0XB0) et
[capteur inductif Omron M18](https://automation.omron.com/en/us/products/family/E2EH/e2eh-x7d1-m1g).
Ces produits guident la silhouette et l’implantation des bornes; les modèles
Blender sont des créations originales sans copie de photos ni de logos.

## Comportements de commande audités

| Appareil | Comportement dans le moteur | Retour visuel |
| --- | --- | --- |
| Temporisateur étoile-triangle | Bobine alimentée → contact étoile; après le délai réglé, étoile s’ouvre; après le temps mort, triangle se ferme. La retombée réinitialise le cycle. | États de bobine, étoile, temporisation et triangle pilotent les voyants; l’image ne commute pas les contacts. |
| PLC AC3 et PLC CC | Programme Ladder exécuté à chaque pas; entrées câblées, contacts NO/NC, timers, mémoires et sorties Q sont lus/écrits par le moteur. Les sorties peuvent commander des bobines de contacteurs. | Voyants d’alimentation, marche et défaut liés à l’état runtime; sorties Q conservées dans l’inspecteur. |
| Verrou mécanique AC3 | Références de deux contacteurs vérifiées; si les deux sont commandés ensemble, le moteur les relâche et émet un diagnostic de conflit. | Le pont sélectionne la position gauche/droite selon le contacteur effectivement maintenu; dessin de secours sinon. |
| Capteur inductif et fins de course | Leur contact NO/NC modifie effectivement la continuité du circuit et l’entrée PLC correspondante. L’actionnement se fait actuellement par commande directe dans l’atelier. | Deux rendus repos/actionné sont sélectionnés selon l’état. Le déplacement d’une cible et la distance de détection du capteur inductif ne sont pas encore simulés. |

Les contrats de commande se trouvent dans `packages/electrosim_controls/` et
le pas runtime dans `apps/electrosim/lib/runtime/electrosim_runtime_engine.dart`
et `electrical_project_runtime_engine.dart`. L’image n’ajoute jamais une loi
électrique au composant.

## Inventaire courant des types de palette

Le catalogue électrique déclare 58 types `modelType`. 33 correspondent au
registre `F18PhysicalPlateAssets.models`; les 25 autres ne sont pas tous des
lacunes, car plusieurs ont des chargeurs d’images spécialisés ou un renderer 3D
dédié. Les lacunes d’images Cycles confirmées sont les capteurs de commande, le
temporisateur, les automates, le verrouillage mécanique et une partie du
catalogue générique. Chaque variante doit encore être contrôlée pour ses bornes
et ses états.
