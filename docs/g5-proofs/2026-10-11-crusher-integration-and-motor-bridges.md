# Broyeur 05 intégré et pontages internes des moteurs

## Intégration locale

Les textures Cycles originales sont intégrées dans l'application : vue en
perspective dans la palette, vue de face sur la platine. La sélection du
broyeur ouvre graphiquement le coffret de maintenance. Les boutons de la
machine restent inactifs, conformément à la décision de l'utilisateur.

Le chargement publie les trois textures atomiquement après contrôle de leurs
dimensions 1440×1320. Un rendu de secours conserve les ancrages si le
chargement échoue. La perspective de palette n'est pas transformée deux fois.
Un broyeur nouvellement ajouté reçoit une enveloppe 480×440 ; les dimensions
personnalisées des anciens projets sont préservées. Cette échelle de
présentation n'est pas une calibration mécanique certifiée en millimètres.

Les bornes U1/V1/W1/W2/U2/V2 sont positionnées dans le coffret avec PE séparé.
Les identifiants et le contrat électrique à six bornes d'enroulements plus terre ne
changent pas. L'emplacement de ce coffret reste pédagogique, pas certifié par
le fabricant de la référence BB300. Les arrivées de phase évitent visuellement
les plots de la rangée inférieure ; le PE utilise un trait vert/jaune.

## Étoile et triangle

Les connexions entre bornes d'un même moteur asynchrone à bornier natif, ou
du broyeur, prennent un chemin local dans le bornier. Elles ne font plus un
tour à l'extérieur de la machine. L'étoile est rendue sur la rangée basse ;
le triangle relie U1–W2, V1–U2, W1–V2 avec des pontages verticaux lorsque le
câblage réel contient ces connexions. Aucun pontage électrique n'est inventé.

Les anciens chemins internes sont réparés à l'ouverture, en conservant les
autres routes, les positions, les rotations, les ancrages personnalisés et les
IDs. Le routeur applique également la règle aux nouveaux tracés. Les pontages
restent visibles au-dessus du rendu du bornier, avec un aspect métallique.

Les autres machines du catalogue encore dotées d'anciens ports haut/bas ne
sont pas déclarées corrigées : elles recevront un bornier compact fondé sur
leurs références photographiques pendant leur reprise 3D, puis cette règle.

## Preuves et vérification

Captures réelles de `F18WorkspacePage`, pas illustrations Blender :

- `crusher-integrated/closed.png` : palette et broyeur de face, coffret fermé.
- `crusher-integrated/maintenance.png` : coffret ouvert, câblage et PE.
- `crusher-integrated/motor-star.png` : moteur asynchrone couplé en étoile.
- `crusher-integrated/motor-delta.png` : moteur asynchrone couplé en triangle.

Le manifeste adjacent consigne tailles et SHA256 des PNG et textures.
20 tests Flutter ciblés réussissent : ancrages, étoile/triangle dans les quatre
orientations, réparation des anciens pontages, idempotence, conservation des
routes indépendantes, défauts PE/RCD, fonctionnement du moteur et captures.
15 contrôles Python du maillage réussissent également.

Analyse statique des fichiers Dart de l'application modifiés : aucune erreur.
La qualification générale à 400 composants, les builds de distribution et
la validation visuelle utilisateur restent à effectuer. Aucun merge G5.
Le broyeur est intégré et testé localement ; sa finition visuelle reste à
valider. Les composants 01–04 gardent leur statut précédent.
