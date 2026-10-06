# F18 — G11 Tests & audits automatiques

## Objectif

G11 transforme les validations par gate en une qualification transversale reproductible.
Aucun code métier du solveur n'est modifié par ce gate : G11 vérifie que l'ensemble
intégré reste cohérent avant la qualification finale G12.

## Portée de l'audit

La qualification G11 couvre simultanément :

- le verrou Flutter 3.38.10 / Dart 3.10.9;
- les contrats statiques de convergence et les contrats F18 G7 à G10;
- l'inventaire de tests et la présence des preuves de chaque gate;
- l'absence de payloads temporaires de construction;
- les décisions UX non-régressives : EIE professeur uniquement, aucun coach élève,
  un seul Supprimer dans la barre supérieure;
- la pureté des bibliothèques produit V2;
- `flutter analyze` et la suite complète de tests de l'application;
- `analyze + test` de chacun des 15 packages;
- les tests explicites de performance/routage du canvas.

## Stratégie CI

Le workflow G11 sépare les charges en jobs indépendants :

1. **static-audit** — contrats Python et manifeste d'audit;
2. **application** — analyse + suite Flutter complète;
3. **dart-packages** — packages Dart purs;
4. **flutter-packages** — canvas et UI kit;
5. **performance** — budget de frame canvas et interactions G6;
6. **gate** — marqueur final uniquement si tous les jobs précédents sont verts.

Le manifeste JSON de l'audit statique est publié comme artefact CI.

## Règle de fermeture

G11 est PASS uniquement si le workflow complet est vert sur le SHA exact de la branche
G11, puis à nouveau vert sur le SHA exact de fusion dans
`v2-post-mac-audit-fixes-20261005`.

G12 ne peut être ouvert avant cette double preuve.
