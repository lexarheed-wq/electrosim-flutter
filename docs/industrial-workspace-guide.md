# Platine, Schéma et armoire

Les boutons **Platine** et **Schéma** utilisent le même circuit, les mêmes bornes et la même simulation. Platine conserve les positions physiques et les visuels des composants. Schéma affiche sur fond blanc les symboles électriques et les connexions, avec une implantation dérivée. Chaque vue conserve son cadrage. Changer de vue annule le geste de câblage ou de déplacement en cours.

Dans le menu **…**, **Configurer l’armoire** règle largeur, hauteur et profondeur en millimètres, avec des formats prédéfinis. La plaque utile conserve une marge intérieure. Le composant sélectionné peut être affecté à l’intérieur, à la porte ou à l’extérieur. Le rail ou la goulotte sélectionné peut être redimensionné. Les encombrements sont génériques ; ils ne constituent pas des dimensions certifiées par un fabricant.

Le placement assisté DIN aligne l’ancrage mécanique du composant sur le rail. Déplacer, redimensionner ou supprimer un rail détache ses fixations sans déplacer les composants. Les limites de montage sont contrôlées lors de l’ajout, du remplacement, du déplacement et de la rotation. Les équipements extérieurs sont libres des limites de la plaque.

**Router via goulottes** utilise les goulottes connectées et vérifie les obstacles. Une liaison impossible conserve son ancien parcours. Cette commande est annulable et ne change jamais les bornes électriques.

**Aperçu 3D** présente les volumes génériques de l’armoire, des supports et des composants. Glisser tourne la caméra ; le bouton de réinitialisation restaure le cadrage. Cette vue est en lecture seule. Les équipements de porte et extérieurs sont identifiés et affichés à une profondeur distincte. Le câblage se fait dans la vue de face.

La sauvegarde de l’implantation utilise le schéma 3 pour les dimensions et les fixations. Les anciens documents de schémas 1 et 2 restent lisibles, sans armoire imposée. Le choix Platine/Schéma est une préférence d’interface séparée du circuit.

La qualification automatisée fournit des captures Flutter et un candidat Mac Intel avec `SOURCE_SHA.txt` et une empreinte SHA-256. Elle ne remplace pas une recette physique sur Mac.
