# Lot 06–15 : dix composants intégrés, revue visuelle en attente

Les liens ci-dessous sont des **captures réelles de F18WorkspacePage**,
avec palette en perspective et platine de face. Chaque PNG mesure 2400×1500.
Aucune image IA et aucune photo fabricant ne remplace un composant de l'interface.

| Composant | Palette et platine | Coffret / bornier | Alimenté par le solveur |
|---|---|---|---|
| Climatiseur | [Vue normale](external-air-conditioner-closed.png) | [Maintenance](external-air-conditioner-maintenance.png) | [Fonctionnement](external-air-conditioner-running.png) |
| Compresseur industriel | [Vue normale](external-compressor-closed.png) | [Maintenance](external-compressor-maintenance.png) | [Fonctionnement](external-compressor-running.png) |
| Congélateur | [Vue normale](external-freezer-closed.png) | [Maintenance](external-freezer-maintenance.png) | [Fonctionnement](external-freezer-running.png) |
| Convoyeur | [Vue normale](external-conveyor-closed.png) | [Maintenance](external-conveyor-maintenance.png) | [Fonctionnement](external-conveyor-running.png) |
| Fer à repasser | [Vue normale](external-iron-closed.png) | [Maintenance](external-iron-maintenance.png) | [Fonctionnement](external-iron-running.png) |
| Mélangeur industriel | [Vue normale](external-mixer-closed.png) | [Maintenance](external-mixer-maintenance.png) | [Fonctionnement](external-mixer-running.png) |
| Ordinateur | [Vue normale](external-computer-closed.png) | [Maintenance](external-computer-maintenance.png) | [Fonctionnement](external-computer-running.png) |
| Pompe triphasée | [Vue normale](external-pump-3p-closed.png) | [Maintenance](external-pump-3p-maintenance.png) | [Fonctionnement](external-pump-3p-running.png) |
| Pompe monophasée | [Vue normale](external-pump-ac1-closed.png) | [Maintenance](external-pump-ac1-maintenance.png) | [Fonctionnement](external-pump-ac1-running.png) |
| Pompe solaire CC | [Vue normale](external-solar-pump-closed.png) | [Maintenance](external-solar-pump-maintenance.png) | [Fonctionnement](external-solar-pump-running.png) |

Les textures ont été rendues avec Blender 4.5.3 LTS, Cycles 32 échantillons,
débruitage OpenImageDenoise, HDR studio et quatre sources rectangulaires. Les
modèles sont originaux. Les anciennes dimensions personnalisées restent
conservées ; chaque nouvelle insertion de la palette a été exercée réellement.

Les quatre entraînements triphasés gardent les pontages étoile et triangle dans
le bornier. Les tests vérifient les pontages et les arrivées de phase dans les
quatre rotations. Les nouveaux ancrages des pompes AC1 et CC restent distincts.
Les fiches/prises, la terre, les défauts d'isolement, le moteur commun et les IDs
utilisateur sont conservés. Les variantes historiques `pump` restent lisibles ;
les nouvelles variantes mono et CC sont différenciées sans changer leur modèle
électrique. La sélection ouvre seulement une vue pédagogique de maintenance.

Les images de fonctionnement proviennent d'un clic réel sur « Lancer » ; les
contrôles vérifient l'état alimenté du composant rendu. Le marqueur logiciel
vert est distinct d'une LED matérielle. Les boutons décoratifs restent inactifs.
L'extérieur du stator du mélangeur ne tourne pas artificiellement.

## Vérification locale

- 57 tests Flutter ciblés réussis, dont 10 captures/essais des appareils du lot
  et 2 captures de non-régression du broyeur et du moteur étoile/triangle.
- Analyse statique des 16 fichiers Dart concernés : aucune erreur ou remarque.
- Générateur de coordonnées Dart vérifié contre le contrat JSON du maillage.
- 30 textures contrôlées : CRC PNG, dimensions, SHA256 et identité de maillage.
- 15 tests Python antérieurs du maillage et du lanceur passent également ; ils
  ne sont pas présentés comme une qualification scientifique des dix appareils.

Les builds de distribution Mac/Chromium et la qualification générale à
400 composants restent différés conformément au document directeur. Le lot
est développé et intégré ; **sa validation esthétique appartient à l'utilisateur**.
Aucune fusion dans G5/main.

Voir [les références et limites](references-and-limits.md) : les positions de
certains coffrets sont pédagogiques, les puissances du catalogue ne sont pas
les fiches des appareils photographiés, et la pompe solaire à deux ports CC
n'est pas une simulation du contrôleur PS2 réel.

Le manifeste [provenance.json](provenance.json) relie chaque capture aux textures
utilisées et à la recette. La recette initiale est archivée au commit
`4501fa16060db24df5afd364edbb0dfea183836b` ; les raccords mécaniques des pompes et
les perçages de semelle du fer ont été repris ensuite. Les autres formes restent
les mêmes ; chaque provenance indique le SHA de sa recette effectivement rendue.

## Reproduction

Depuis la racine du dépôt, avec Blender et Dart disponibles :

```bash
python3 tools/g5_3d_remaining/generate_lot_geometry.py --check
blender -b --factory-startup -t 3 --python-exit-code 1 --python tools/g5_3d_remaining/render_lot_06_15.py -- --out build/g5_lot_06_15 --samples 32
```

Les fichiers `front.png`, `palette.png`, `service.png` vérifiés sont copiés dans
`apps/electrosim/assets/g5_industrial/<clé>-<vue>.png`. Puis, depuis l'application,
avec `FLUTTER_ROOT` défini pour charger les vraies polices de capture :

```bash
flutter test --no-pub test/g5_lot_06_15_geometry_test.dart test/g5_lot_06_15_migration_test.dart tool/capture_g5_lot_06_15_test.dart
```

Les PNG d'interface sont écrits dans `apps/electrosim/build/g5-lot-06-15-proof/`.
`--dart-define=G5_PROOF_KEYS=external-iron` limite la capture à une identité, sans
changer le rendu de production. Les anciennes preuves PNG restent accessibles
dans l'historique Git ; les nouveaux fichiers sont les preuves de ce lot.

## Appuis des pompes et châssis du mélangeur

Les captures du mélangeur et des trois pompes ont été renouvelées après la
[correction des appuis](support-correction.md). Les pattes sont reliées aux
carters ; le châssis roulant supporte le mât, et la tête de mélange reste
suspendue. 31 tests Flutter ciblés et les contrôles structurels des quatre
maillages passent. Les empreintes actualisées figurent dans `provenance.json`.
