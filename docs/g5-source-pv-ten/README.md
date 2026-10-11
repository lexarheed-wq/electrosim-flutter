# Lot de dix — sources, interrupteur et photovoltaïque

Branche séparée `feat/g5-source-pv-ten-20261010`, au-dessus du lot de diodes/LED
(PR 84). Dix équipements ciblés, dix nouvelles géométries Cycles originales :

| Entrée ciblée | Géométrie |
|---|---|
| Interrupteur NO | `switch-toggle` |
| Source CC 24 V | `source-dc-voltage` |
| Source de courant CC | `source-dc-current` |
| Source AC 230 V | `source-ac-voltage` |
| Source de courant AC | `source-ac-current` |
| Champ photovoltaïque | `solar-panel` |
| Régulateur MPPT | `controller-mppt` |
| Régulateur PWM | `controller-pwm` |
| Batterie photovoltaïque | `solar-battery` |
| Onduleur solaire | `solar-inverter` |

Les trois variantes monophasées L1/L2/L3 et le champ PV haute tension partagent
ces géométries : quatorze entrées du catalogue bénéficient de ce lot, sans les
présenter comme quatorze boîtiers nouvellement conçus.

## Références photographiques

Photos téléchargées et inspectées hors dépôt, sans photographie commerciale
embarquée ni texture provenant de ces produits :

- [Interrupteur SPST à levier et bornes à vis](https://cdn.webshopapp.com/shops/188510/files/214266731/1000x1000x2/spst-heavy-duty-toggle-switch-with-screw-terminals.jpg) : corps isolant, support métallique, bague filetée, écrou hexagonal et levier poli.
- [Alimentation de laboratoire](https://s.alicdn.com/%40sc04/kf/H0c861ac6898c400ea0103b7aa665dafft/New-Model-Longwei-LW3010KDS-30V-10A-Adjustable-Switching-Regulated-DC-Bench-DC-Power-Supply-Variable-with-4-Digits-Displaying.jpg) : boîtier métallique, afficheur, encodeurs, ventilation et sorties.
- [Source programmable AC](https://rexgear.com/cdn/shop/files/it7300-series-linear-programmable-ac-power-supply-857811.jpg?v=1716254275) : afficheur et ventilation d'un équipement de banc.
- [Régulateur MPPT](https://cdnsolar.ca/cdn/shop/files/SmartSolarMPPT100-30_front.png?v=1683959159) : capot moulé, ailettes et raccordements à vis.
- [Régulateur PWM](https://www.solar4rvs.com.au/cdn/shop/files/12_24_5ah4.webp?v=1771376809&width=1200) : écran LCD et boutons distincts du MPPT.
- [Batterie scellée](https://www.akkushop-schweiz.ch/thumbnail/9e/54/a3/1679500864/yuasanp1212_n001_ef1e53f63027731464cca0a7cc3796a9212ee4fe_1920x1920.jpg) : bac isolant, couvercle, joints et cosses.
- Le panneau et l'onduleur utilisent aussi les [photos déjà documentées](../g5-industrial-next/README.md) dans les lots précédents.

Les modèles sont génériques et adaptés au contrat de présentation d'ElectroSim.
Ils ne reproduisent ni une marque, ni une certification, ni les caractéristiques
nominales des produits photographiés. L'AC adopte un format de banc adapté au
gabarit existant, sans prétendre être une reproduction dimensionnelle du rack.

## Conservation des fonctions

Les modèles électriques, paramètres de solveur, identifiants de ports et
dimensions Canvas sont conservés. Les positions visuelles évoluent pour les
régulateurs (quatre raccords intégrés à la partie basse) et la batterie (deux
cosses sur le couvercle). Les prises des sources sont creuses ; la batterie
emploie des lames Faston percées plutôt que des têtes de vis universelles.

À la reprise d'un projet, la migration reconnaît les anciennes surcharges
d'ancre du MPPT/PWM et de la batterie, et invalide les routes PV devenues
diagonales avec les nouveaux ports. Les positions, rotations, IDs électriques,
rails/goulottes et autres ancres personnalisées restent conservés. Les routes
valides ne sont pas effacées à chaque réouverture.

Le panneau possède un véritable boîtier arrière 3D ouvert, avec contacts et
diodes de dérivation représentés. Deux sorties seulement restent électriques ;
les contacts intermédiaires ne créent pas de ports dans le solveur. Une action
« Voir le bornier arrière » ouvre le détail tout en gardant la vue de face sur
la platine. Le contenu se défile sur les petits écrans.
MPPT, PWM et onduleur conservent quatre bornes : aucun port USB ou sortie charge
non simulé n'est ajouté d'après les photos.

Le levier possède des poses 3D qui suivent `closed`. Les afficheurs reçoivent
les tensions/courants déjà projetés par l'application. Une source désactivée
n'affiche pas une valeur de mesure inventée. La palette utilise les valeurs
nominales de sa définition ; la platine utilise celles de l'instance/runtime.
La charge de batterie suit `batterySoc`, avec indication SOC pédagogique ;
elle ne représente pas une mesure physique certifiée ou un LCD fabricant.

Les images sont chargées une fois et partagées entre les instances. Les
changements de courant ne déclenchent un nouveau dessin des afficheurs de
source que pour les sources. Le rendu antérieur reste disponible lorsqu'un
ensemble de vues ne peut pas être chargé.

## Preuves et qualification

Les captures sont générées avec les widgets de production et l'interface
réelle, dans les deux vues, simulation arrêtée. Elles ne qualifient pas un
circuit électrique alimenté ni une performance à 400 composants.

Qualification des dernières corrections en cours ; les captures et résultats
antérieurs ne prouvent pas ces nouveaux raccordements. Les résultats définitifs
sont consignés dans VALIDATION.md après exécution.

```bash
# Depuis apps/electrosim
flutter test --no-pub test/g5_source_pv_ten_test.dart
flutter test --no-pub test/g5_industrial_physical_assets_test.dart
flutter test --no-pub tool/capture_g5_industrial_test.dart
```

Depuis la racine :

```bash
ELECTROSIM_INDUSTRIAL_MODELS=switch-toggle,source-dc-voltage,source-dc-current,source-ac-voltage,source-ac-current,solar-panel,controller-mppt,controller-pwm,solar-battery,solar-inverter ELECTROSIM_RENDER_SAMPLES=64 blender -b --factory-startup -t 4 --python tools/render_g5_industrial.py
```
