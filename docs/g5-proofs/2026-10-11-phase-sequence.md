# Contrôleur de phases — lot 01 / composant 04

Référence examinée : photo officielle Fluke 9040, téléchargée le 11/10/2026. Cette date indique la consultation, pas la date de lancement. Le modèle logiciel est original, sans logo fabricant ni certification CAT reproduite.

## Géométrie retenue
Boîtier antichoc jaune, façade graphite, LCD haut en format vertical, trois sorties de cordons fixes sur le haut. Pas de vis fictives, de prises inférieures A/COM, de fusible ou de sélecteur de multimètre. Textes/ordre/flèche sont calculés par Flutter à partir de la mesure ; aucun résultat n'est inscrit dans la texture.

## Fonctionnement préservé
Ports `phase1`, `phase2`, `phase3`, identifiants de sondes, topologie et modèle de calcul préexistants conservés. Image originale de face sur la platine, perspective unique dans la palette, rotation partagée par le corps, le LCD et les sorties de cordons. Chargement atomique des deux images et repli sur le visuel antérieur si le chargement échoue.

## Vérifications effectuées
- Test initial rouge : aucune RawImage propre dans la palette. Après intégration : deux tests de capture Flutter passent, ordre direct et inversé.
- Quatre tests électriques passent : six permutations, sonde absente/duplicata/neutre, référence de borne inexistante refusée par le domaine, monophasé et instrument OFF.
- Treize tests ciblés instruments passent, puis quatre captures phase/fréquence passent. Analyse Dart des quatre fichiers de production sans erreur.
- Deux vues originales Cycles 1120×1520/96 échantillons produites ; seconde passe pour arrondis et sorties de câble cylindriques terminée. Les deux captures Flutter ont été régénérées et les deux essais passent.

## Limites
La qualification est celle de la projection AC3 actuelle ; aucun seuil de tension ou comportement harmonique spécifique au matériel Fluke n'est revendiqué. Le lot de dix reste en cours. Aucun composant n'est déclaré validé par l'utilisateur et aucune fusion dans G5/main n'est effectuée.

Captures PNG directes : [ordre direct](phase-sequence/workspace-forward.png), [ordre inversé](phase-sequence/workspace-reversed.png).

Après la seconde passe, 13 tests supplémentaires passent : deux captures de phases et qualification des identités/visuels du catalogue. Les libellés de famille fictifs des appareils externes sont retirés ; leurs bornes et valeurs techniques restent présentes.
