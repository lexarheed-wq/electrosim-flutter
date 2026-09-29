# Audit approfondi F8-R7 — Canvas, gestes, robustesse et dette avant F9

**Statut de phase : CANDIDAT — F8 non validée physiquement.**  
F0 à F7 ont franchi leurs portes sur le Mac Monterey de référence. F8 reste bloquée tant que `F8_GATE_PASS`, la revue des trois goldens et l'ouverture graphique n'ont pas été obtenus sur ce Mac.

## 1. Périmètre audité

L'audit couvre `electrosim_canvas`, l'application de démonstration F8, les tests widget/golden/performance, les scripts de validation et les frontières avec le noyau Dart. Les références fonctionnelles sont le cahier des charges directeur, notamment les sections UX/Canvas, responsive, stratégie de tests et la porte F8.

## 2. Résultat synthétique

| ID | Sujet | Sévérité | État R7 | Décision |
|---|---|---:|---|---|
| F8-A01 | Tolérance de hit-test dépendante du zoom | Haute UX | Corrigé R7 | Tolérances désormais exprimées en pixels écran puis converties en unités monde |
| F8-A02 | Annulation de câblage incomplète | Haute UX | Corrigé R7 | Clic sur fond ou re-clic sur la borne active annule proprement l'opération |
| F8-A03 | Sélection d'un fil sans feedback visuel | Moyenne | Corrigé R7 | Fil sélectionné rendu avec couleur/épaisseur de sélection |
| F8-A04 | Collision d'identifiants visuels inter-types | Haute robustesse | Corrigé R7 | Échec explicite plutôt qu'écrasement/ambiguïté silencieuse |
| F8-A05 | Surlignage des bornes compatibles absent | Moyenne | Ouvert | Préparé pour F9/interactions, sans inventer de règle électrique dans le Canvas |
| F8-A06 | Sémantique/accessibilité par élément absente | Moyenne | Ouvert | À traiter dans F9 avec navigation clavier et Semantics ciblées |
| F8-A07 | Composants dessinés comme cartes génériques | Attendu | Ouvert | Intentionnel avant F9 : langage visuel professionnel à créer |
| F8-A08 | `shouldRepaint` force le repaint | Basse/Perf | Ouvert | Acceptable pour F8 si benchmark vert ; optimiser seulement après profilage |
| F8-A09 | Géométrie reconstruite lors de chaque hit-test | Basse/Perf | Ouvert | Surveiller avec gros circuits ; cache interdit tant qu'aucune mesure ne le justifie |
| F8-A10 | Double-clic basé sur `DateTime.now()` | Basse | Ouvert | Suffisant F8 ; injection d'horloge à considérer si flakiness observée |

## 3. Corrections R7

### F8-A01 — Hit-testing stable quel que soit le zoom

Avant R7, `HitTestEngine` recevait un point en coordonnées monde et utilisait directement `terminalRadius=11` et `wireTolerance=7` comme unités monde. Le rendu des bornes/fils étant exprimé en pixels écran, la zone cliquable variait fortement avec le zoom.

R7 transmet `viewportScale` au moteur de hit-test et convertit la tolérance écran en tolérance monde :

`toléranceMonde = toléranceÉcran / scale`

La cible tactile/souris reste donc approximativement constante en pixels. Un test couvre zoom avant et zoom arrière.

### F8-A02 — Annulation explicite du câblage

R7 nettoie `_pendingTerminalId` et `_pointerWorldPosition` lorsque :

- l'utilisateur reclique la borne de départ ;
- l'utilisateur clique le fond ;
- une connexion est effectivement demandée.

Un test vérifie que `borne A → fond → borne B` ne déclenche aucune connexion fantôme.

### F8-A03 — Feedback de sélection d'un fil

Le clic sur un fil renvoyait déjà son `connectionId`, mais le painter ne montrait aucun état sélectionné. R7 applique `selectionColor` et une épaisseur de 5 px au fil sélectionné. Le modèle électrique reste inchangé.

### F8-A04 — Collision d'identifiants visuels

Le domaine utilise des types d'ID distincts (`ComponentId`, `SourceId`, `ConnectionId`) et peut donc légalement contenir la même chaîne dans plusieurs catégories. F8 utilisait en revanche une clé graphique `String`, ce qui pouvait créer une ambiguïté de layout/sélection.

R7 bloque explicitement toute collision de chaîne entre source, composant et connexion dans `CircuitGeometryIndex`. Cela évite une corruption visuelle silencieuse. Une migration vers une clé graphique typée pourra être étudiée ultérieurement, sans modifier le contrat électrique.

## 4. Conformité architecturale

Conforme statiquement :

- aucun import du solveur, de la topologie, des mesures, de l'énergie ou du PV dans `electrosim_canvas` ;
- `CircuitState` est reçu en entrée et n'est jamais muté ;
- `CircuitVisualLayout` porte uniquement l'état graphique ;
- le déplacement émet un callback et ne modifie pas le circuit ;
- le câblage émet un callback de demande et ne fabrique pas une connexion électrique dans le Canvas ;
- le viewport ne modifie que l'échelle et la translation visuelles ;
- hit-testing centralisé.

## 5. Gaps non bloqués dans R7 mais à traiter avant UX finale

### Compatibilité des bornes

Le cahier des charges demande de surligner les cibles compatibles pendant le câblage. F8 ne doit pas calculer cette compatibilité lui-même. La bonne architecture pour F9 est :

`Application/Domain compatibility policy → IDs de bornes compatibles → Canvas → feedback graphique`

Le Canvas ne doit recevoir que la décision ou un prédicat, jamais réimplémenter les règles électriques.

### Accessibilité

Le Canvas possède une sémantique globale, mais pas encore :

- focus clavier par composant ;
- description de borne ;
- action clavier équivalente au clic ;
- navigation sans souris ;
- annonces d'état sélection/câblage.

Ces éléments sont intégrés au plan F9.

### Performance à grande échelle

Le benchmark F8 mesure 24 composants et 23 connexions. R7 ne crée aucun cache prématuré. Avant toute optimisation, il faudra mesurer au minimum 50/100/250 éléments et distinguer : paint, hit-test et rebuild widget.

## 6. Porte de sortie F8

F8 ne pourra être déclarée validée qu'après :

1. analyse Flutter verte ;
2. tests widget verts, y compris les tests R7 ;
3. goldens compact/medium/expanded générés, inspectés et approuvés ;
4. benchmark p95 sous 16 667 µs sur la scène nominale ;
5. ouverture réelle sur macOS Monterey ;
6. validation manuelle de la checklist `F8_PHYSICAL_VALIDATION_CHECKLIST.md` ;
7. `F8_GATE_PASS`.

## 7. Décision

**NO-GO vers F9 tant que les preuves physiques F8 ne sont pas disponibles.**  
La conception F9 peut être préparée, mais aucun lot F9 ne doit être déclaré implémenté ou validé.
