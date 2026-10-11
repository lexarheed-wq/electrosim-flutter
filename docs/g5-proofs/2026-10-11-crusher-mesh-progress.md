# Broyeur 05 — progression du maillage, pas qualification du produit

Référence photographique du fabricant :
https://www.retsch.com/products/milling/jaw-crusher/bb-300/

Photo téléchargée et examinée :
https://www.retsch.com/assets/images/c/main_bb300-32z9pkjepempwf9.png

Le modèle original reproduit une trémie à quatre parois, un ensemble de
concassage caréné, un capot latéral fermé à contour courbe, un socle et une
commande d'arrêt. Aucun rouleau exposé ni rotation extérieure fictive.

Le bornier ouvert optionnel est une **vue pédagogique de maintenance**.
Ses six plots sont les extrémités des enroulements du moteur, pas six entrées
d'alimentation de la machine. Un septième contact est réservé au PE.
La photo ne permet pas de vérifier la position du bornier réel : sa position
sur ce maillage reste une proposition, à distinguer d'une reproduction exacte.
Le maillage présente désormais un capot fermé en vue normale. L'option
`service_open=True` du générateur expose les contacts pour les futurs essais
de maintenance ; elle n'est pas encore accessible depuis ElectroSim.

Le bornier a été déplacé hors de la silhouette du capot latéral : le premier
essai de rendu montrait plusieurs plots masqués par le capot. Les contrôles
locaux vérifient les six coordonnées distinctes, le PE séparé, la séparation
avec le capot et le refus d'une identité de composant incorrecte.

Rendus de travail : `build/g5_sequential/external-crusher/{front,palette}.png`.
Ce sont des sorties Blender, **pas des captures de la palette ou de la platine**.
L'adaptateur Dart, les ancrages des fils, la migration des anciens projets et
les preuves Flutter restent à réaliser avant de qualifier le composant 05.
Les composants 01–04 restent les seuls qualifiés dans cette série.

Vérification locale : `python3 -m unittest discover -s tools/tests -v` :
15 tests réussis, dont quatre contrôles du maillage du broyeur.
Les tests du maillage ne valident pas le moteur électrique ni l'interface.

## Reprise après rejet du premier prototype

La silhouette seule et le bornier en façade ne suffisaient pas. Les photos
de détail des pages 4–5 de la fiche fabricant ont été examinées :
https://www.retsch.com/files/452889/fiche-produit-bb-300.pdf

Une photo de plus grande taille a également été téléchargée :
https://www.retsch.com/assets/images/s/main_bb300-khcjv45jfskj9rz.png

Corrections du maillage : volant plein et vis hélicoïdale à la place de la
roue à rayons inventée ; poignée de blocage ; plaque de réglage graduée ;
commande rotative ; conduits avec attaches et presse-étoupe ; accès au
concassage avec joint, brides et fermeture ; lèvres et bride de trémie ;
capot à joint et fixations ; collecteur démontable ; rondelles et boulons
hexagonaux ; enveloppe du moteur arrière avec ailettes.

La texture passe de 960×880 à 1440×1320, sans changement de coordonnées
logiques. Les normales des arêtes et l'exposition ont été corrigées.
Le débruitage OpenImageDenoise est une option explicite du lanceur, vérifiée
avec Blender 4.5.3 ; les autres composants gardent leur configuration.

L'éclairage du broyeur utilise désormais quatre softboxes rectangulaires
orientées vers la machine : source principale, bande de reflet latérale,
contour supérieur et remplissage frontal. Les tôles peintes ont un vernis
diélectrique et une rugosité modérée ; l'acier des mécanismes est métallique
et anisotrope. La peinture blanche n'est pas transformée en chrome.
La direction d'extrusion du capot a été corrigée : son épaisseur doit rester
derrière sa face, sans espace noir artificiel. Le lanceur force également
un code de sortie non nul sur erreur Python dans Blender.
Le capot possède maintenant une face légèrement bombée maillée en anneaux,
plutôt qu'une face plane : ses normales varient sur la surface pour produire
des reflets de studio continus.

## Commandes de la machine : décision de périmètre

Les commandes sont géométriques, rendues dans les PNG ; elles ne sont
**pas interactives**. L'utilisateur a autorisé leur maintien inactif tant
que leur utilité dans ElectroSim n'a pas été démontrée. Leur interactivité
ne bloque donc pas la qualification visuelle du composant. Aucun clic
fictif ni animation de commande sans effet électrique n'est ajouté.

Si une fonction utile est définie ultérieurement, son intégration devra vérifier :

- Zone de clic/toucher alignée avec la commande rotative, même après rotation
  ou zoom de la platine, sans empêcher la sélection ou le déplacement.
- Marche/arrêt commandant réellement les branches d'alimentation du modèle,
  pas seulement une animation ou un booléen graphique.
- Commande d'arrêt prioritaire, état affiché cohérent et pas de redémarrage
  automatique inattendu après son relâchement.
- Fonctionnement triphasé et défaut d'isolement/PE inchangés, en arrêt comme
  en marche selon l'emplacement physique du défaut.
- Aucun couplage fictif entre le volant mécanique et la simulation électrique :
  une modification de charge par réglage nécessite un modèle mécanique défini.

Ces comportements n'ont pas été codés ni testés pour ce nouveau broyeur.

Cette version reste une reconstruction originale inspirée du BB300,
avec certains détails de montage approximatifs et un coffret pédagogique.
Elle ne constitue pas une réplique cotée certifiée par le fabricant.
