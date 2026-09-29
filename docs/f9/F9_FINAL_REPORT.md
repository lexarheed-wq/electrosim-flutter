# F9 FINAL — Rapport d’achèvement candidat

## Base

- Base fonctionnelle : F8-R11 validée physiquement (`F8_GATE_PASS`).
- Dernière validation intermédiaire reçue : F9-R13 (`F9_R13_GATE_PASS`).
- Cible hôte : macOS Ventura 13.7, Flutter 3.38.10 / Dart 3.10.9.
- Le noyau F1→F8 et les 54 fichiers gelés restent inchangés.

## F9.1 — Design system

- tokens sémantiques UI séparés des codes électriques ;
- thème Material 3 ;
- surfaces, panneaux, statuts et cibles tactiles minimales de 48 px.

## F9.2 — Shell et navigation

- accueil à trois entrées ;
- navigation persistante de session : Accueil / Tableau de bord / Gérer la session ;
- dashboard : Câblage / Recherche de dérangement / Supervision ;
- Centre de maintenance entre directement en Recherche de dérangement ;
- Centre de conception entre directement en Câblage.

## F9.3 — Responsive

- compact `<600` : Canvas prioritaire, panneaux en overlay ;
- medium `600–1000` : Canvas + un panneau secondaire ;
- expanded `>1000` : Palette + Canvas + contexte ;
- barre d’état responsive sans overflow connu ;
- changement de breakpoint sans mutation de `CircuitState` couvert par test.

## F9.4 — Palette et identité composant

- recherche, catégories, Voir plus/Voir moins, ajout `+` et drag & drop ;
- allocation d’identifiants sans collision ;
- placement automatique évitant composants et conducteurs ;
- 12 composants pilotes CC ;
- glyphes canoniques partagés palette/Canvas via `F9ComponentGlyph` et `F9CanvasVisualOverlay` ;
- les 217 éléments legacy restent une taxonomie de référence, sans import automatique.

## F9.5 — Panneaux contextuels

- Propriétés : type, id, bornes, paramètres, état, bascule explicite, remplacement, suppression sûre ;
- Mesures : conteneur prêt, aucune grandeur inventée sans `MeasurementEngine` ;
- EIE : conteneur prêt, aucun diagnostic spéculatif sans preuves moteur ;
- Diagnostic : visible uniquement pour un élève en Recherche de dérangement.

## F9.6 — Feedback de câblage

- politique de compatibilité explicite `F9WiringPolicy` ;
- rejet des doublons et des phases explicitement incompatibles ;
- création réelle d’une `Connection` et incrément de révision lorsqu’elle est valide ;
- feedback accessible via barre d’état + SnackBar ;
- Échap réinitialise l’état d’interaction du Canvas sans modifier le circuit.

## F9.7 — Accessibilité

- Semantics sur actions principales et palette ;
- statuts en `liveRegion` ;
- sélection d’élément accessible au clavier via liste dans Propriétés ;
- alternative aux actions de contexte par boutons explicites ;
- raccourcis Échap / zoom clavier ;
- cibles principales ≥48 px.

## F9.8 — Goldens et porte finale

Jeu de références prévu :

- compact 390×844 : base, palette, propriétés ;
- medium 820×1180 : base, palette, propriétés ;
- expanded 1440×900 : base, palette, propriétés ;
- compact élève Recherche de dérangement : diagnostic.

Le premier `./validate.sh` génère ces références si elles n’existent pas et retourne `F9_GATE_GOLDEN_REVIEW_REQUIRED`. Après revue visuelle, `python3 tools/approve_f9_goldens.py --approve` fige leurs SHA-256. Le rerun doit retourner `F9_GATE_PASS`.

## Hors périmètre F9

- valeurs de mesure réelles : phase dédiée aux moteurs de mesure ;
- diagnostic EIE calculé : phase EIE dédiée ;
- bibliothèque complète de schémas sains : F10 ;
- scénarios de panne autonomes : F11 ;
- workflows TP : F12.

F9 n’invente donc aucune vérité électrique pour remplir ses panneaux.
