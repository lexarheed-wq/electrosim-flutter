# Bornes physiques et zones de connexion

Branche : feat/g5-3d-sequential-26-components. Aucune fusion dans G5.

## Modifications qualifiées

- Suppression des pastilles métalliques génériques de la couche d'interaction.
- Halos au survol au repos, à la sélection, à l'origine d'un câble et sur les
  cibles acceptées pendant le câblage. Nom de la borne au survol.
- Bouton « Afficher les bornes » sur la platine. Sortir du canvas efface le survol.
- Les coordonnées et identifiants des connexions restent inchangés.
- Rendus Cycles 96 échantillons : LED rouge/verte, résistance axiale,
  condensateur film, inductance, diodes axiale/verre/TVS. Suppression des faux
  borniers et des vis systématiques sur ces composants nus. Pattes des LED
  sans coude à angle droit, terminant aux points électriques existants.
- Les connecteurs industriels réels conservent leurs vis.
- Cordons voltmètre/ampèremètre : fiches frontales, poignées isolées,
  garde-doigts, métal au contact de la borne. Légendes frontales vectorielles.

## Vérification réelle

10 tests passent dans la campagne bornes : capture du workspace Flutter avec
survol, bouton réversible et circuit identique ; centres des contacts dans les
assets ; multisélection ; projection schématique ; fiche frontale.
8 tests supplémentaires passent pour projection/commandes du voltmètre et
capture du circuit passif de 120 Ω. Le test de préférences de représentation a
échoué dans une première campagne puis passe isolément : ce résultat ne
constitue pas une qualification exhaustive de la restauration asynchrone.
Analyse statique des quatre fichiers de production : aucune erreur ou warning,
une information préexistante de style dans f18_workspace_page.dart.

Captures produites directement par Flutter, sans retouche :
- build/g5-terminal-proof/workspace-hidden-terminals.png
- build/g5-terminal-proof/workspace-visible-terminals.png
- build/g5-sequential-proof/instrument-voltmeter/workspace-120-ohm.png

La fixture LED est volontairement refusée par l'ohmmètre (composant non linéaire)
et affiche N/A : aucune résistance fictive n'est inventée. La mesure 120 Ω est
vérifiée séparément sur un circuit purement passif.

## Références des cordons

Photos téléchargées comme références de conception uniquement, non distribuées
comme assets de l'application :
https://www.fluke.com/en-us/product/accessories/test-leads/fluke-tl75
https://media.fluke.com/8e47ab44-bfd4-4dfc-b774-b108002f1a64_original__size.jpg

## Portée

Ce lot ne qualifie pas les 26 composants du document directeur. Les nouveaux
rendus et l'interaction ne modifient pas le solveur ; la qualification scientifique
multi-ampèremètres reste une tâche distincte en cours sur cette branche.
