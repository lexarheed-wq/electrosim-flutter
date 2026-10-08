# Rendu industriel ElectroSim — livraison et intégration

Base du travail : `09f0459dd584c6231870387e7d5f8d8dd77b647d` sur la branche
`core-island01-prebaseline-r3-20261008`. Le code est isolé dans
`feat/professional-workspace`. La branche actuelle de l'utilisateur sera fournie
plus tard ; elle n'a pas été remplacée ou fusionnée.

## Rendu réalisé

La maquette sert de référence esthétique. Le résultat est un rendu vectoriel
Flutter détaillé, pas une reproduction photographique pixel par pixel.

- Disjoncteurs, contacteurs et relais thermique : proportions plus étroites,
  boîtiers englobant les bornes, vis, ponts isolants, arêtes et états mécaniques.
- Boutons NO/NC : même empreinte étroite, bague métallique, relief, contacts
  inférieurs intégrés. Le changement d'état reste fourni par le runtime existant.
- Moteur triphasé : carter bleu, ailettes, pieds, flasque, arbre et boîte à six
  bornes. Ordre logique U1/V1/W1/U2/V2/W2 conservé ; rangée physique inférieure
  W2/U2/V2. Le peintre et les zones cliquables utilisent la même géométrie.
- Rails métalliques : rainures, oblongs et vis de fixation. Supports décoratifs
  dérivés des appareils DIN déjà alignés et des plaques génériques de boutons
  sur la même rangée ; ils ne déplacent, n'accrochent et ne
  connectent aucun appareil. Les appareils tournés ne reçoivent pas de rail
  horizontal trompeur. La disposition est calculée une fois par peintre.
- Fils : courbures bornées par la longueur des segments, ombre, reflet et
  épaisseur adaptée au zoom. Endpoints et waypoints électriques inchangés.
  L'animation du courant suit les mêmes courbures que le fil visible.
- Repères des composants : placés sous le boîtier réel, sans ancienne limite de
  hauteur qui les faisait apparaître dans les boîtiers hauts.
- Polices explicites sur les peintres concernés pour rendre les captures lisibles.

## Différentiel : distinction nécessaire

`ResidualCurrentVisual` fournit le dessin indépendant d'un différentiel 2P/4P,
avec manette, bouton de test, inscriptions et bornes intégrées en haut et en bas.
Ce widget ne calcule pas le courant résiduel, ne déclenche pas de protection et
n'est pas ajouté au catalogue fonctionnel de cette branche. Le moteur disponible
ne contient pas de modèle différentiel associé. Les valeurs nominales affichées
sont les paramètres explicites du widget de dessin, pas des mesures simulées.

Si la branche actuelle possède déjà ce modèle électrique, utiliser le widget et
ses `terminalOffsets` pour adapter ce modèle après vérification de l'ordre des
bornes. Ne pas mapper un différentiel vers un simple disjoncteur.

## Compatibilité et intégration

Les nouveaux fichiers du canvas doivent être intégrés avec leur export dans
`electrosim_canvas.dart`. Intégrer ensemble `canvas_geometry.dart`,
`f18_component_asset_visual.dart`, `f14_library_components.dart`,
`f17_three_phase_components.dart` et les peintres de référence : le dessin et les
ancres ne doivent pas provenir de deux versions différentes.

Les identifiants électriques et le format CircuitState ne sont pas modifiés.
Les dimensions par défaut concernent les nouveaux placements. Un circuit dont
la mise en page impose déjà une ancienne taille peut conserver cette taille ;
les peintres s'y adaptent. Les ancres du moteur et du bouton NC ont évolué :
vérifier/rerouter les fils de ces appareils après ouverture d'une ancienne
géométrie. Les routes personnalisées ne sont pas effacées automatiquement.

Comparer le patch à la branche cible. Ne pas remplacer aveuglément `main.dart`,
les peintres ou les fichiers de géométrie qui auraient été modifiés en parallèle.

## Vérification et captures

Exécuter `flutter analyze` et `flutter test` dans `apps/electrosim`,
`packages/electrosim_canvas` et `packages/electrosim_ui_kit`.

Depuis `apps/electrosim`, exécuter :

```sh
flutter test tool/capture_professional_workspace_test.dart
flutter test tool/capture_industrial_plate_test.dart
```

`ELECTROSIM_UI_CAPTURE_DIR` choisit le dossier de sortie ;
`ELECTROSIM_FONT_DIR` pointe vers les polices Material du SDK Flutter.
La vue `industrial-plate.png` est une scène de validation des vrais peintres :
circuit triphasé sans alimentation, différentiel séparé non raccordé, pas un
nouveau mode de l'application. Les autres captures représentent les pages
réelles de l'application sur ordinateur, tablette et téléphone.

Les widget tests ne prouvent pas une cadence de 60 Hz avec 400 appareils sur un
téléphone réel. Qualifier cet objectif en mode profile/release sur la machine
cible. Les modèles scientifiques et les défauts de sauvegarde des circuits
identifiés avant la refonte ne sont pas corrigés par une modification du rendu.

## Revue indépendante et corrections

La revue du lot UI et des nouveaux rendus n'a établi aucun défaut Critical ou
Important. Ses deux constats Minor ont été corrigés :

1. L'action accessibilité Augmenter de l'inspecteur augmente désormais sa
   largeur. Le sens du glisser du séparateur et des flèches physiques est conservé.
2. Une édition de disposition est sauvegardée même si le stockage natif se résout
   après la fermeture de la page. Un ordre réservé à l'édition empêche une page
   ancienne d'écraser une modification plus récente sur le même fichier.

Les tests ciblés ont reproduit les défauts/API absentes avant correction ;
les 9 tests de préférences et les 24 tests UI kit passent après correction.

Les décisions de réalisation du lot A sont conservées dans son rapport :
worktree existant isolé, suivi manuel du plan, breakpoints spécifiques à
l'atelier, annulation des gestes au redimensionnement, références golden mises
à jour après contrôle des captures. Aucune fusion de branche distante n'a été
nécessaire pour fournir ce code.

## Résultats de qualification

La dernière exécution complète passe : 286 tests application, 88 tests canvas
et 24 tests UI kit, soit 398 tests Flutter. Passent également 8 scénarios de capture, trois
analyses Flutter sans problème, 4 tests Python de contrat et audit F18-G11
sans erreur. Les 7 pages capturées passent les contrôles de cibles tactiles et
libellés ; la scène de platine est la huitième capture.

Un premier passage complet a trouvé un seul écart golden de quatre pixels,
chacun limité à un cran sur un canal RGB. Les formes et positions étaient
identiques. Les références ont été régénérées avec le rendu final, sans
assouplir le comparateur ni les assertions d'interaction ; la suite complète
a été réexécutée après cette mise à jour : les 286 tests passent.

