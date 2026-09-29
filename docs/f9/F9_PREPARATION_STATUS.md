# F9 — Dossier de préparation uniquement

**F9 n'est pas ouverte officiellement.** Ce dossier prépare les décisions de design, responsive, accessibilité et validation afin de pouvoir démarrer immédiatement après `F8_GATE_PASS`.

Aucun fichier de production F9 n'est ajouté dans ce lot. Les documents décrivent une cible d'implémentation, pas une fonctionnalité déjà disponible.

## Entrées de référence

- architecture en couches : UI au-dessus du Canvas et du noyau ;
- profils responsive : compact `<600`, medium `600–1000`, expanded `>1000` ;
- aucune zone essentielle inaccessible ;
- design system cohérent ;
- cohérence graphique palette/platine ;
- goldens desktop/tablette/mobile ;
- audit accessibilité ;
- zéro overflow critique ;
- la qualité visuelle ne doit jamais modifier la vérité électrique.

## Sorties préparées

- `F9_DESIGN_SYSTEM_SPEC.md` ;
- `F9_RESPONSIVE_LAYOUT_SPEC.md` ;
- `F9_COMPONENT_VISUAL_LANGUAGE.md` ;
- `F9_ACCESSIBILITY_AND_INPUT_SPEC.md` ;
- `F9_GOLDEN_AND_ACCEPTANCE_PLAN.md` ;
- `F9_IMPLEMENTATION_PLAN.md`.

## Condition d'ouverture

F9 ne commence qu'après preuve `F8_GATE_PASS` + contrôle visuel F8.

## Durcissement R8

R8 ajoute un contrat UX consolidé, une architecture de l'information, un audit visuel de la référence historique, un modèle d'état UI, une matrice responsive par écran, une matrice d'acceptation, une taxonomie visuelle couvrant les 217 entités historiques **sans les importer**, trois captures historiques de référence et un contrôle automatisé `tools/f9_preflight_check.py`.

Le contrôle préflight vérifie explicitement que F9 reste fermée : aucun fichier Dart de production ne doit encore exister dans `electrosim_ui_kit`.


## Durcissement R10

R10 ajoute la spécification détaillée des familles de composants, la grammaire des bornes, la matrice d'états, le jeu de pilotes, la matrice QA, les vagues futures d'implémentation et une empreinte cryptographique du code Dart de production F8. Le but est de pouvoir démarrer F9 sans improviser lorsque `F8_GATE_PASS` sera confirmé, tout en prouvant qu'aucun code de production n'a été modifié pendant cette préparation.
