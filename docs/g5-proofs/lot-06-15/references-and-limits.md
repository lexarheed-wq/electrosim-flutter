# Références examinées et écarts explicites — composants 06 à 15

Les photos originales ont été téléchargées pour comparaison locale puis examinées.
Elles ne sont pas redistribuées comme textures dans l'application. Les PNG intégrés
sont des rendus Cycles de maillages originaux ; les preuves d'interface sont des
captures Flutter distinctes. Le manifeste photo donne URL, date et SHA256. Une
photo ancienne d'une gamme toujours au catalogue n'est pas annoncée comme une
photo ou un modèle de 2026.

| Appareil | Référence fabricant | Éléments repris dans la géométrie originale |
|---|---|---|
| Climatiseur | [Daikin Sensira FTXF-D](https://www.daikin.eu/en_us/products/product.html/FTXF-D.html), gamme [FTXF-E/RXF-E](https://www.daikin.eu/en_us/products/product.html/FTXF-E---RXF-E.html) également consultée | Façade galbée, capot ABS, sortie à volets, prise d'air supérieure, accès électrique à droite. Photo de construction FTXF-D, pas copie exacte du FTXF-E. |
| Compresseur | [Atlas Copco Automan Silent AC](https://www.atlascopco.com/de-de/compressors/products/air-compressor/piston-compressor/professional-piston-compressor/ac-series-silent) | Carénage graphite, bande cyan, joints et portes, manomètre, arrêt, aérations et pieds. |
| Congélateur | [Liebherr CFd 2505](https://www.liebherr.com/en-ae/p/cfd-2505-3245759) | Rapport largeur/hauteur du coffre, couvercle et joint, poignée, charnières, commande à droite et pieds. |
| Convoyeur | [Dorner 2200 Belted](https://www.dornerconveyors.com/products/2200-series/2200-belted-conveyor) | Bande, rails aluminium à rainures, paliers et brides, support réglable, motoréducteur latéral. Le socle et le moteur sont une adaptation industrielle. |
| Fer | [Tefal Ultimate Pure FV9844](https://shop.tefal.gr/products/ultimate-pure-sidero-atmoy-fv9844) | Poignée ouverte, réservoir turquoise, semelle étroite, molette et commandes, sortie du cordon sur le talon. |
| Mélangeur | [Silverson Batch Mixers](https://www.silverson.com/us/products/batch-mixers) | Mât mobile, moteur vertical à ailettes, support triangulé, arbre et tiges sanitaires, tête rotor/stator, roulettes. |
| Ordinateur | [Lenovo ThinkCentre M70a Gen 6](https://www.lenovo.com/us/en/p/desktops/thinkcentre/m-series-aio/lenovo-thinkcentre-m70a-gen-6-24-inch-intel/len102c0060) | Écran tout-en-un à bord fin, caméra à cache, colonne et pied réglable, dessous ventilé. |
| Pompe triphasée | [Pedrollo CP](https://www.pedrollo.com/prodotto/superficie/centrifughe-monogiranti-e-bigiranti/centrifughe-monogirante/cp/) | Volute à brides et raccords creux, nervures, boulons et bouchon, moteur horizontal à ailettes, bornier supérieur/latéral. |
| Pompe monophasée | [Pedrollo CP](https://www.pedrollo.com/prodotto/superficie/centrifughe-monogiranti-e-bigiranti/centrifughe-monogirante/cp/) | Version plus compacte et capot de condensateur, raccordement L/N/PE. La même photo de famille sert de comparaison de volumes ; ce n'est pas une photo vérifiée d'une variante CPm précise. |
| Pompe solaire | [LORENTZ PS2 / pompes de surface](https://www.lorentz.de/products-and-technology/products/ps2-solar-pumping-systems/) | Pompe verticale multicellulaire, moteur sombre, enveloppe inox, tirants, raccords et socle. |

## Les raccordements visibles ne constituent pas des plans de fabrication

Les photos extérieures ne montrent pas toutes les borniers ouverts. Les six plots
AC3 suivent le montage industriel U1/V1/W1 et W2/U2/V2 dans un coffret compact,
mais la position exacte, les dimensions et les possibilités d'accès de chaque
modèle fabricant n'ont pas été certifiées. Les coffrets ouverts sont donc des
vues pédagogiques de maintenance. Les appareils mobiles gardent une fiche et un
cordon ; leurs bornes internes ne deviennent pas une prise ajoutée en façade.
Le raccordement fixe reste sélectionnable dans les propriétés, comme auparavant.

Les identifiants électriques, classes de protection configurées, valeurs
résistives/inductives et puissances du catalogue ElectroSim sont conservés. Ils
ne sont pas remplacés par les valeurs d'un appareil photographié. En particulier,
la pompe solaire conserve le modèle CC à deux ports ; elle ne simule pas le
contrôleur PS2, son MPPT ou son moteur ECDRIVE réel. Aucun contrôleur implicite
n'est inventé par le dessin. Les pompes AC1 restent des charges d'impédance.
Les enveloppes de platine donnent des proportions de présentation cohérentes,
pas une échelle certifiée en millimètres de tous les matériels du catalogue.

## Fonctionnement visible

La bande du convoyeur reçoit des marques de déplacement synchronisées à la phase
existante du moteur. Le stator extérieur du mélangeur reste immobile, comme sur
un vrai mélangeur ; son rotor est enfermé. Le climatiseur, le fer, le compresseur
et le congélateur réagissent visuellement à l'alimentation, sans fausse valeur de
température ou de pression. L'écran de l'ordinateur affiche un visuel abstrait
lorsqu'il est alimenté. Un petit marqueur logiciel vert, hors des surfaces de la
machine, indique l'activité des appareils carénés. Ce n'est pas une LED physique.

Les boutons décoratifs ne sont pas interactifs, conformément au périmètre
explicitement autorisé. La simulation et la protection de terre continuent de
passer par le moteur électrique existant. L'aspect de la platine et ses rails
ne sont pas modifiés dans ce lot.
