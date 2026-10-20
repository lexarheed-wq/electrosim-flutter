# Manifeste unifié comme source des géométries

## Objectif

Faire du manifeste `apps/electrosim/assets/g5_industrial/geometry.unified.json` la source unique des coordonnées et dimensions des 27 modèles intégrés lors des lots de géométrie 3D, sans changer leur rendu ni les comportements du simulateur.

## État constaté

- 26 modèles natifs ont une entrée avec `size`, `ports`, `board_size`, `service_box` et `three_phase` dans le manifeste.
- Ces 26 entrées correspondent aux dimensions, bornes, coffrets et indicateurs de phase du catalogue Dart actuel.
- `external-crusher` est le 27e modèle. Son rendu passe déjà par un visualiseur 3D dédié; son manifeste expose `size`, `ports` et `ports_7t_extra`, sans `board_size` ni `service_box`.
- Les contrats Blender et `generate_lot_geometry.py` dupliquent actuellement une partie de ces données géométriques.
- Le chargeur unifié des composants industriels reste opt-in via `ELECTROSIM_UNIFIED_GEOMETRY`; son comportement par défaut ne change pas.

## Comportement attendu

1. Le générateur du catalogue natif lit la géométrie des 26 modèles directement dans le manifeste et produit le même catalogue Dart synchrone, avec les mêmes clés, types visuels, variantes, coordonnées, coffrets et indicateurs de phase.
2. Les contrats des rendus Blender ne conservent que les paramètres propres à la fabrication de l’image ou de la vue de service. Les dimensions, bornes et rectangles qui existent dans le manifeste en sont retirés et sont fusionnés depuis celui-ci au lancement du rendu.
3. La recette Blender du broyeur lit sa taille et ses bornes depuis son entrée du manifeste. Son visuel spécialisé et ses vues de service restent inchangés. La borne de terre optionnelle continue d’utiliser `ports_7t_extra`.
4. Le chargeur historique et le mécanisme opt-in du manifeste ne changent pas. Aucun mode n’est activé par défaut.
5. Aucune image, aucun matériau ni aucune géométrie 3D n’est retouché dans ce changement.

## Validation

- Un contrôle Python hors Flutter vérifie les 27 entrées, les dimensions, la présence et les limites des bornes, les références d’images et la correspondance entre manifeste, sortie générée et métadonnées Blender restantes.
- Le mode `--check` du générateur échoue si le fichier Dart généré n’est plus à jour.
- Un test Dart continue de vérifier l’adaptateur opt-in, la compatibilité avec les données historiques et le format du manifeste.
- `git diff --check` est exécuté.
- Les tests Flutter ne sont déclarés réussis qu’après exécution réelle. Dans l’environnement actuel, le runtime Flutter s’arrête avant les tests car macOS refuse `sysctl` dans le sandbox; aucun contournement n’est autorisé.

## Hors portée

- Activer le manifeste unifié par défaut.
- Modifier les comportements électriques, les placements, les routes ou les états des composants.
- Remplacer le rendu spécialisé du broyeur par le rendu natif générique.
- Refaire ou régénérer des images Blender.
- Résoudre l’interdiction `sysctl` du sandbox.
