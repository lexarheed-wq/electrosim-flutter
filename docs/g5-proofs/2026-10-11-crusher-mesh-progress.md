# Broyeur 05 — progression du maillage, pas qualification du produit

Référence photographique du fabricant :
https://www.retsch.com/products/milling/jaw-crusher/bb-300/

Photo téléchargée et examinée :
https://www.retsch.com/assets/images/c/main_bb300-32z9pkjepempwf9.png

Le modèle original reproduit une trémie à quatre parois, un ensemble de
concassage caréné, un capot latéral fermé à contour courbe, un socle et une
commande d'arrêt. Aucun rouleau exposé ni rotation extérieure fictive.

Le bornier présenté ouvert est une **vue pédagogique de maintenance**.
Ses six plots sont les extrémités des enroulements du moteur, pas six entrées
d'alimentation de la machine. Un septième contact est réservé au PE.
La photo ne permet pas de vérifier la position du bornier réel : sa position
sur ce maillage reste une proposition, à distinguer d'une reproduction exacte.
Il faut prévoir un capot fermé pour la présentation normale et une ouverture
de maintenance pour accéder au bornier dans ElectroSim.

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
13 tests réussis, dont deux nouveaux contrôles du maillage du broyeur.
Les tests du maillage ne valident pas le moteur électrique ni l'interface.
