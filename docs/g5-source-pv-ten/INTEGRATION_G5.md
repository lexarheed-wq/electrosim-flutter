# Consolidation des travaux dans G5

Cible : `feat/g5-industrial-geometry-20261009`. Base distante observée avant intégration : `5e7b75c`.

Les branches et SHA inclus sont répertoriés dans `integration-branches.json`. Les dix nouveaux composants s’ajoutent aux passifs, diodes et LED. Les précédents travaux d’interface professionnelle, de rendu de référence, de catalogue, de platine métallisée et de routage incrémental sont tous présents dans l’historique consolidé.

Sont aussi inclus le document directeur pneumatique, les tests d’isolation électrique P2 et les qualifications pneumatiques R6/A et R6/B déjà empilées sur G5.

## Résolution des branches historiques

L’ancienne interface professionnelle contenait des versions dépassées du moteur, de la palette et du workspace monolithique. La résolution conserve le workspace actuel séparé, ses fonctionnalités électriques et pneumatiques, la représentation platine/schéma, les rails et les dimensions des moteurs à bornier latéral. Les ajouts encore manquants sont transférés : sauvegarde tardive après sortie de page, ordre des écritures entre pages et augmentation accessible de l’inspecteur.

La première branche locale des passifs est reconciliée avec la version des passifs déjà qualifiée sur la base P3 ; aucune ancienne géométrie ne remplace les nouveaux équipements. L’ancienne branche du correctif de connexion est déjà intégrée sous un autre commit : sa fusion conserve le moteur et le worker actuels.

Les branches historiques externes à ces travaux et les prototypes WIP supersédés ne sont pas des versions candidates à réintroduire. Cette consolidation ne remplace pas la qualification native macOS et ne certifie pas l’ensemble des composants selon une norme industrielle.
