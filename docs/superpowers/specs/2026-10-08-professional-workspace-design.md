# ElectroSim — atelier professionnel

Statut : proposition visuelle approuvée dans la conversation ; spécification écrite à relire avant plan d’implémentation.

## Objectif

Mettre en œuvre la direction « atelier technique contemporain » approuvée : un circuit lisible au centre, des commandes accessibles et des animations brèves, sans compromettre le câblage, les fonctions pédagogiques ou les optimisations de connexion déjà fusionnées.

Référence de code : commit `09f0459dd584c6231870387e7d5f8d8dd77b647d`. La maquette générée est une référence d’apparence ; ses marques, valeurs et raccordements ne constituent pas un circuit électrique validé. Les visuels de production conservent les composants génériques d’ElectroSim.

## Décisions de présentation

- Bandeau bleu nuit pour l’identité, le contexte et les actions principales ; surfaces de travail claires ; accent bleu pour la sélection.
- Palette gauche, circuit central, inspecteur droit, statut inférieur. Un volet de résultats vient ensuite sous le circuit, alimenté par les mesures existantes.
- Panneaux ancrés et redimensionnables sur grand écran. Pas d’auto-fermeture au survol. Le masquage reste explicite.
- Hiérarchie constante : contexte du document, action disponible, résultat/état. Aucun bouton décoratif présenté comme une fonctionnalité opérationnelle.
- Les couleurs de conducteurs gardent leur signification électrique ; la palette de l’interface n’impose pas leur recoloration.

## Livraison progressive

### A — coque et ergonomie

Réorganiser la coque existante, actualiser les tokens et la barre d’actions, conserver les actions métier et les composants existants. Ajouter redimensionnement des panneaux, commandes de visibilité accessibles, transitions et respect de la réduction des animations. Corriger le chevauchement de Mesures, la superposition compacte et les cibles tactiles.

### B — interaction et lecture du matériel

Améliorer les retours de sélection, les bornes compatibles et les commandes directes déjà présentes. Ajouter une présentation mécanique des changements d’état validés : levier, bouton et voyant. L’état électrique est immédiatement transmis au moteur ; l’animation représente cet état, sans le retarder. Tester les bornes aux quatre rotations.

### C — fonctions nouvelles liées à la maquette

Développer séparément l’historique annuler/rétablir, les favoris, les mesures regroupées et la vue Schéma. Ces fonctions ne sont pas toutes présentes dans le code actuel : elles ne doivent pas être simulées par des boutons inactifs. La vue Schéma utilise les mêmes identifiants et connexions que la platine, mais sa propre géométrie. Son modèle de présentation et son historique font l’objet d’une conception dédiée avant codage.

L’accueil, les bibliothèques et les parcours de session restent fonctionnels pendant ces étapes. Le moteur électrique ne change pas dans A ou B.

## Disposition adaptative

### Grand écran — largeur d’au moins 1200 pixels logiques

Barre supérieure permanente, avec hauteur minimale de 64 px et hauteur adaptable au texte. Palette initiale 264 px, réglable entre 220 et 360 ; inspecteur initial 304 px, réglable entre 280 et 440. Respecter une zone centrale minimale de 480 px. Si cette contrainte cesse d’être possible, basculer vers la disposition intermédiaire plutôt que recouvrir les contrôles.

Statut permanent en bas, minimum 40 px mais extensible au texte. Les séparateurs possèdent une poignée avec alternative clavier et des tailles bornées. Les commandes restent à l’extérieur des zones de contenu défilant.

### Écran intermédiaire — 720 à 1199 px

Barre et statut visibles ; un seul panneau latéral à la fois, largeur maximale 304 px. Priorité à l’inspecteur lorsqu’un composant est sélectionné, sans ouvrir automatiquement un panneau qui masquerait une manipulation en cours. Les commandes secondaires vont dans un menu clairement nommé.

### Écran compact — moins de 720 px

Barre à hauteur minimale de 56 px, pouvant se répartir sur deux lignes ; accès permanent aux composants, propriétés et simulation. Un seul tiroir modal ou volet inférieur est ouvert. Il occupe au maximum la zone entre barre et statut et dispose d’une fermeture de 48×48 px. Échap et retour système ferment le volet et rendent le focus à son déclencheur. Aucun survol requis.

### Texte agrandi

À 150 % et 200 %, autoriser croissance verticale, libellés sur plusieurs lignes et formulaires verticaux. Les menus portent les fonctions qui ne tiennent plus, avec libellés et infobulles. Ne pas traiter « aucune exception de layout » comme preuve suffisante : vérifier que les actions restent atteignables.

## Contrat de géométrie du circuit

La coque définit la taille et l’origine du viewport ; le layout du circuit reste en coordonnées du monde. Un redimensionnement ne modifie ni les positions sauvegardées des composants ni les routes de fils.

Préserver le point du monde au centre de la zone visible lorsque les panneaux sont ouverts, fermés ou redimensionnés. Geler les interactions de séparation pendant un geste de câblage/déplacement, ou annuler proprement ce geste avant changement de viewport. Ne jamais convertir un déplacement de panneau en déplacement du circuit.

Le drop de palette convertit sa position globale au RenderBox du canvas puis au monde. Dessin, hit-test, aperçu de fil et calcul du drop partagent cette conversion. L’action de recentrage cadre le circuit dans la zone centrale visible, pas dans la fenêtre entière.

## Architecture et fichiers concernés

- `packages/electrosim_ui_kit/lib/src/workspace_shell.dart` : composition responsive, état des panneaux, tailles, séparateurs et navigation. Conserver le contrat public des widgets fournis et les clés de régions utilisées par l’application ; faire évoluer les tests qui supposent le masquage automatique.
- `packages/electrosim_ui_kit/lib/src/design_tokens.dart` : couleurs d’interface, contours, espacement, durées et géométrie. Garder les couleurs électriques distinctes.
- `packages/electrosim_ui_kit/lib/src/electrosim_theme.dart` : style des contrôles, focus, champs et surfaces ; ne pas assombrir automatiquement toutes les pages pour obtenir le bandeau de l’atelier.
- `apps/electrosim/lib/main.dart` : adapter `_WorkspaceTopBar`, `_StatusBar` et le raccordement au viewport ; conserver les callbacks actuels, autorisations des élèves et navigation de session.
- Palette et inspecteur : ajuster titres, formulaires et densité avec les widgets existants ; conserver remplacement, propriétés, mesures, preuves de calcul et EIE.
- Canvas : seulement les changements nécessaires à la stabilité du viewport et aux retours de manipulation. Ne pas réintroduire un reroutage global sur chaque frame d’animation.

L’état d’ouverture et les tailles sont gérés par un contrôleur de disposition indépendant de l’état électrique. Les listeners de simulation actuels restent localisés. Isoler le canvas dans une frontière de repaint ; animer la chrome sans reconstruire le graphe électrique.

Mémoriser les préférences de disposition dans un espace versionné distinct du document électrique. Restaurer des tailles bornées et revenir aux valeurs par défaut si la préférence est invalide. L’implémentation choisira l’adaptateur de préférences compatible avec les plateformes déjà prises en charge, sans détourner la sauvegarde du circuit.

## Transitions

| Élément | Comportement |
|---|---|
| Ouverture/fermeture de panneau | 180–220 ms, décélération sans rebond ; cibles/focus inactifs dès la fermeture. |
| Changement d’inspecteur | 120–160 ms, transition légère sans déplacer un champ en cours d’édition. |
| Sélection | Retour immédiatement visible ; contour discret, sans oscillation répétitive. |
| Déplacement et aperçu de fil | Suivi direct du pointeur, sans interpolation qui éloigne la borne du curseur. |
| Zoom | Centré sur le pointeur ; les mises à jour successives ne s’accumulent pas dans une file d’animations. |
| Commande mécanique | Animation courte de la pièce mobile ; le moteur reçoit immédiatement l’action. |
| Lampe | Valeur issue du modèle ; pas de rampe physique inventée pour un modèle sans dynamique. |

Respecter `MediaQuery.disableAnimations` et la préférence système : durée nulle ou simple changement d’état. Tout ticker se met en pause lorsque son widget est hors écran ou que son effet est terminé. Éviter flous de grande surface et ombres animées sur tous les composants.

## Actions et fiabilité

Lancer/mettre en pause, réinitialiser, domaine électrique, recentrer, rotation, suppression, ouvrir/enregistrer et navigation de session conservent leurs conditions de disponibilité. Ne pas contourner le mode élève en lecture seule.

Le statut distingue simulation arrêtée/en cours et erreurs déjà disponibles. Un indicateur Enregistré ne paraît qu’après réussite confirmée de l’écriture ; aucun nouveau bandeau ne doit donner une assurance que la persistance actuelle ne fournit pas. Les défauts de sauvegarde documentés restent un chantier séparé, signalé dans la livraison.

Mesures et propriétés utilisent le snapshot réellement associé au circuit. Une transition visuelle ne peut pas rendre une ancienne mesure comme si elle était nouvelle. Pas de courbe transitoire fictive ni de référence fabricant supposée validée.

## Validation obligatoire

1. Régression reproduite : cliquer réellement sur Mesures avec les barres visibles et les panneaux ouverts ; vérifier le résultat du clic, pas seulement la présence du texte.
2. Desktop : ouverture, fermeture et redimensionnement avec positions du monde conservées ; recentrage utile ; onglets accessibles.
3. Compact 390×844 et intermédiaire : un panneau à la fois, fermeture, retour du focus, ajout et sélection opérationnels.
4. Texte 150 % puis 200 % : actions et champs utilisables, défilement fonctionnel.
5. Contrôles tactiles : cibles de 48×48 px et libellés sémantiques ; clavier et réduction des animations.
6. Interactions électriques : ajout par drop et bouton, connexion entre bornes après changement de disposition, déplacement, rotation, sélection multiple et suppression ; préserver la protection des sessions élèves.
7. Tests existants : UI kit, navigation, shell, palette, inspecteur, instruments, TP et actions de barre. Mettre à jour uniquement les attentes rendues obsolètes par la nouvelle disposition.
8. Captures comparables avant/après, avec rendu des polices vérifié pour ne pas confondre un artefact du test avec un défaut produit.
9. Performance à 400 composants en profile/release sur machine cible : ouverture de panneau, déplacement, zoom et clic de connexion ; relever p50/p95 et frames lentes. Objectifs : interaction ordinaire <100 ms et budget 16,7 ms à 60 Hz, sans annoncer une garantie avant mesure.

Les tests automatisés locaux ne remplacent pas les essais sur appareil ni les essais VoiceOver. Les limites de plateforme et de performance sont indiquées dans la livraison.

## Livrables

Une branche de développement dédiée, des changements testés, des captures avant/après et un compte rendu de validation. Préparer une PR GitHub avec portée exacte et limites ; la fusion dépend d’une instruction explicite pour cette nouvelle refonte. L’autorisation de fusionner la correction de performance précédente ne vaut pas demande de fusion de ce nouveau chantier.

## Relecture de cette spécification

Points à valider : disposition adaptative, stabilité du viewport, animations légères et livraison en trois étapes. Le développement du lot A commencera après validation de cette spécification puis du plan d’implémentation. La maquette ne promet pas une copie photographique pixel par pixel ni des fonctionnalités de simulation absentes du moteur.
