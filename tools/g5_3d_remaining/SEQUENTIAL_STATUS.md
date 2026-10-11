# G5 / 26 composants 3D — développement séquentiel

Date d'origine : 11 octobre 2026.
Branche de travail unique : `feat/g5-3d-sequential-26-components`.
**INTERDICTION DE FUSION** dans G5/main avant validation humaine des **26/26 visuels et preuves PNG**. Cette interdiction inclut les PR #103 et #107.
**Preuves** : toujours fichiers PNG directs (deux vues et captures réelles Flutter), jamais envoyer de ZIP comme preuve.
**Ordre** : finir chaque composant, puis passer au suivant sans demander de validation intermédiaire.
**Qualification** : garder les essais Mac Intel et Chromium, ainsi que la campagne GitHub de qualification générale, pour la fin des 26. Les captures sont uniquement de vrais rendus logiciels, pas des images IA.
**Non-régression** : contrats de ports/sondes/TerminalId, branchements, solveur, animation, persistance et rendu de repli.

## Inventaire ordonné

| N° | Clé | Développement et preuve |
|---:|---|---|
| 01 | `instrument-voltmeter` | Voltmètre 3D et boutons existants conservés ; mesure Ω codée par source 1 V / 1 kΩ TEMPORAIRE ; réseau ouvert désormais OL explicite ; cas série/parallèle/ouvert/alimenté créés mais NON exécutés ; preuves utilisateur/qualification différées |
| 02 | `instrument-ammeter` | Recette Blender originale A/COM/fusible + rendu Cycles paramétré ; loader dédié, palette/frontale/câbles/contrôles et tests Dart écrits ; construction.json explicite et référence photographique marquée INCOMPLÈTE (3 douilles sur photo contre 2 A/COM dans le contrat) ; PNG non générés ; qualité visuelle/mesure réelle NON qualifiées |
| 03 | `instrument-frequency` | En attente de son tour |
| 04 | `instrument-phase-sequence` | En attente de son tour |
| 05 | `external-crusher` | En attente de son tour |
| 06 | `external-air-conditioner` | En attente de son tour |
| 07 | `external-compressor` | En attente de son tour |
| 08 | `external-freezer` | En attente de son tour |
| 09 | `external-conveyor` | En attente de son tour |
| 10 | `external-iron` | En attente de son tour |
| 11 | `external-mixer` | En attente de son tour |
| 12 | `external-computer` | En attente de son tour |
| 13 | `external-pump-3p` | En attente de son tour |
| 14 | `external-pump-ac1` | En attente de son tour |
| 15 | `external-solar-pump` | En attente de son tour |
| 16 | `external-refrigerator` | En attente de son tour |
| 17 | `external-refrigerator-dc` | En attente de son tour |
| 18 | `external-tv` | En attente de son tour |
| 19 | `external-fan-ac1` | En attente de son tour |
| 20 | `external-fan-3p` | En attente de son tour |
| 21 | `pv-resistive-load` | En attente de son tour |
| 22 | `source-ac3-grid` | En attente de son tour |
| 23 | `source-ac3-alternator` | En attente de son tour |
| 24 | `load-wye-3p` | En attente de son tour |
| 25 | `load-delta-3p` | En attente de son tour |
| 26 | `impedance` | En attente de son tour |

## Méthode par appareil
Recette Blender originale → front et perspective palette → composants interactifs, bornes/sondes → raccordement solveur/runtime → tests locaux → PNG Flutter réel → passer à l'élément suivant. **Ne pas fusionner**, même si des tests techniques sont verts. Ne jamais compter une recette non rendue comme un visuel validé.

### Observations d'environnement
Sur le poste de développement de cette conversation, ni Flutter/Dart ni Blender ne sont installés. Les tests de la branche séquentielle sont rédigés mais n'ont pas été exécutés localement. La qualification de ces sources et les PNG réels seront produits sur les runners finaux ; ne jamais afficher une illustration IA comme preuve de capture Flutter.

### Rapport ponctuel — 11/10/2026 (session)
- Ordre strict : composant 01 traité au niveau du code, composant 02 ampèremètre en développement ; composant 03 non ouvert.
- Composant 01 : injection électrique Ω 1 V / 1 kΩ sur copie déconnectée, refus de toute source et d'élément actif, préflight réseau ouvert OL ; tests ajoutés mais NON exécutés.
- Composant 02 : recette Blender A/COM/fusible, loader et rendu face/3-4 conditionnels, fonctions HOLD/RANGE/SELECT/LIGHT, cordons souples de sondes, tests non exécutés.
- Contrat de construction : photo de référence à trois douilles, modèle logiciel ampèremètre à deux ports de mesure A/COM ; divergence documentée sans inventer de troisième borne.
- État global : 0 fusion, 0 nouveau PNG Flutter/Blender qualifié pendant cette session, pas de lancement de qualification générale ; Mac Intel et Chromium reportés.
