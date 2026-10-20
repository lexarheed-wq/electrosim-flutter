# Plan — source géométrique unifiée des 27 modèles

## 1. Verrouiller le contrat actuel avec des contrôles hors Flutter

- Ajouter `tools/tests/test_unified_geometry_source.py`.
- Vérifier les 26 entrées natives contre `NativeApplianceGeometry.catalogue` : `type`, `variant`, `size`, `board_size`, `ports`, `service_box` et `three_phase`.
- Vérifier les 27 entrées complètes du lot, les fichiers d’images et les bornes dans le cadre. Traiter `external-crusher` selon son modèle spécialisé (`ports` et `ports_7t_extra`).
- Vérifier les règles de fusion des données Blender spécifiques au rendu.
- Exécuter le contrôle avant les changements de génération et constater les écarts attendus.

## 2. Ajouter une lecture et une validation partagées du manifeste

- Créer `tools/g5_3d_remaining/unified_geometry_contract.py` pour lire la version 1 du manifeste et fournir les dimensions, bornes, coffrets et variantes aux outils de rendu.
- Dériver le rectangle Blender centré depuis `service_box`; conserver uniquement dans les contrats les métadonnées non présentes dans le manifeste et nécessaires à la recette (par exemple la hauteur Z, le type de borne ou l’échelle des détails).
- Ajouter une validation claire des clés requises, des bornes et des références d’images.

## 3. Faire générer le catalogue natif depuis le manifeste

- Modifier `tools/g5_3d_remaining/generate_lot_geometry.py` pour lire les 26 entrées natives du manifeste au lieu de fusionner les trois contrats de lot.
- Garder le type visuel et la variante depuis le manifeste et préserver l’API synchrone de `NativeApplianceGeometry`.
- Faire produire le même catalogue actuel, puis prendre en charge `--check` comme contrôle de génération déterministe.

## 4. Réduire les contrats Blender à leurs données spécifiques

- Adapter `render_lot_06_15.py` et les vérificateurs des lots pour fusionner manifeste + paramètres Blender au moment de l’exécution.
- Supprimer des fichiers de contrats les copies de dimensions, ports, tailles de platine et coffrets déjà détenues par le manifeste.
- Inclure le hash du manifeste dans la provenance des rendus pour identifier la géométrie utilisée.
- Modifier `external_crusher_recipe.py` afin de récupérer taille, bornes et borne de terre optionnelle depuis `external-crusher` dans le manifeste, sans changer son mesh spécialisé.

## 5. Vérifier l’intégration et préserver le comportement livré

- Exécuter `python3 -m unittest tools.tests.test_unified_geometry_source` et les contrôleurs structurels Python liés aux lots concernés.
- Exécuter `python3 tools/g5_3d_remaining/generate_lot_geometry.py --check`.
- Exécuter `git diff --check` et examiner le diff ciblé pour confirmer qu’aucune image, logique électrique ou sélection opt-in n’a changé.
- Tenter les tests Flutter ciblés seulement si le runtime démarre. S’il échoue avant le lancement des tests sur `sysctl` dans le sandbox, rapporter ce blocage sans tenter de le contourner.

## Exécution

Plan exécuté en ligne dans le checkout courant. Aucun commit ni publication n’est inclus.

## Résultats

- `python3 -m unittest tools.tests.test_unified_geometry_source -v` : 10 contrôles réussis, dont la parité de l’adaptateur avec les géométries et contrôles historiques, la présence des vues face/palette des 27 modèles et le rejet des dimensions/bornes invalides.
- `PYTHONPATH=tools/tests python3 -m unittest test_g5_crusher_mesh_contract -v` : 4 contrôles réussis.
- `python3 tools/g5_3d_remaining/generate_lot_geometry.py --check` : réussi.
- Comparaison avec la version Dart de départ : les 26 géométries natives restent identiques au manifeste.
- Validation directe des 267 références d’images du manifeste : aucun chemin manquant ou sortant du dossier d’assets.
- Le workflow Mac Intel du projet mixte cible maintenant la branche de base réellement utilisée par la PR 144 et exécute ces contrôles Python; les chemins des outils et tests sont aussi inclus dans ses filtres `push`.
- Vérification syntaxique Python en mémoire et `git diff --check` : réussis.
- Blender a été essayé en arrière-plan pour le contrôle structurel, mais plante avant l’exécution du script Python pendant la détection de son backend Metal (code 139). Les contrôles de géométrie Blender restent donc non vérifiés dans cet environnement.
- Les tests Flutter/Dart ne sont pas qualifiés : le runtime Flutter avait déjà été arrêté avant les tests par le refus de `sysctl` du sandbox; le formatteur Dart s’est également arrêté par `SIGABRT`. Aucun contournement du sandbox n’a été tenté.
