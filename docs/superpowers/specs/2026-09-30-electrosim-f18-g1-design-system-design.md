# ElectroSim F18-G1 — Design System Figma → Flutter

**Date :** 30 septembre 2026  
**Base :** `main@591b8d6386de36093ed22deaab785c38245f5331`  
**Programme :** F18 — Parité produit V1 → Flutter  
**Gate :** G1 — Design System Figma  
**Statut :** design validé en conversation ; spécification écrite à relire avant plan d’implémentation.

## 1. Objectif

G1 établit une **source de vérité visuelle externe au code** afin d’éviter de reproduire l’erreur F9 consistant à figer par golden une interface techniquement stable mais insuffisamment aboutie.

La cible n’est pas de redessiner tout ElectroSim en une seule étape. G1 doit créer :

1. un système de tokens visuels cohérent ;
2. une bibliothèque de composants d’interface fondamentaux ;
3. une grammaire visuelle électrotechnique ;
4. quatre écrans de référence ;
5. une correspondance traçable Figma → Flutter ;
6. un gate empêchant toute dérive visuelle ou moteur non autorisée.

La V1 reste la référence minimale de maturité produit. Flutter conserve son architecture F17 qualifiée.

## 2. Décision d’architecture

Approche retenue : **hybride Design-System-First**.

### Rejeté : code-first

Améliorer directement Flutter puis recopier dans Figma est rejeté car les goldens pourraient figer à nouveau une interface non validée visuellement.

### Rejeté : Figma exhaustif avant tout code

Dessiner l’ensemble d’ElectroSim avant implémentation est rejeté car trop monolithique et risqué vis-à-vis des contraintes réelles du Canvas.

### Retenu : foundations → composants → références → tokens Flutter

G1 définit d’abord les fondations et quelques écrans complets dans Figma. Ensuite seulement, les tokens sont matérialisés dans `electrosim_ui_kit`. Les écrans métiers seront reconstruits dans G2/G3 à partir de ces fondations.

## 3. Périmètre G1

### Inclus

- palette de couleurs UI ;
- couleurs électriques ;
- typographie ;
- échelle d’espacement ;
- rayons ;
- élévations ;
- dimensions de contrôle ;
- états interactifs ;
- règles d’accessibilité ;
- composants d’interface de base ;
- contrat visuel des composants électriques ;
- quatre écrans de référence ;
- mapping Figma ↔ Flutter ;
- tests de cohérence des tokens ;
- gate G1.

### Exclus

- réécriture des écrans métier ;
- catalogue complet de composants électriques ;
- nouveaux solveurs ;
- logique de TP ;
- nouvelles fonctions LAN ;
- animations métier complexes ;
- export PDF/CSV ;
- refonte du Canvas.

## 4. État actuel à remplacer ou renforcer

Le package `electrosim_ui_kit` contient déjà :

- `ElectroSimColors`;
- `ElectroSimSpacing`;
- `ElectroSimRadii`;
- `ElectroSimMotion`;
- `ElectroSimGeometry`;
- `ElectroSimTheme`;
- `ElectroSimBreakpoints`.

Ces éléments sont conservés comme point de départ, pas comme vérité finale.

Le système actuel souffre principalement de trois limites :

1. tokens partiels, non reliés à une source Figma ;
2. composants visuels électriques encore proches de glyphes schématiques génériques ;
3. goldens historiques utilisés comme référence sans validation visuelle externe suffisante.

## 5. Structure du fichier Figma G1

Le fichier doit contenir exactement **trois pages principales**. Cette adaptation a été validée après constat de la limite Figma Starter à trois pages ; elle ne réduit aucun livrable fonctionnel.

### 5.1 Foundations

Sections obligatoires :

- Color / UI semantic ;
- Color / Electrical ;
- Typography ;
- Spacing ;
- Radius ;
- Elevation ;
- Geometry ;
- Motion ;
- Focus & states ;
- Accessibility notes.

### 5.2 Components

Composants fondamentaux minimum :

- Primary button ;
- Secondary button ;
- Tertiary/text button ;
- Icon button ;
- Search field ;
- Text field ;
- Select/dropdown ;
- Toggle ;
- Checkbox ;
- Radio ;
- Chip/status ;
- Card ;
- Navigation item ;
- Toolbar action ;
- Segmented control ;
- Tabs ;
- Palette item ;
- Property row ;
- Inspector section ;
- Status bar item ;
- Empty state ;
- Inline error ;
- Toast/snackbar ;
- Dialog.

Chaque composant possède variantes de taille, état et interaction si pertinentes.

### 5.3 Electrical System

Cette page regroupe deux sections indépendantes : `Electrical Visual Language` et `Reference Screens`.

#### 5.3.1 Electrical Visual Language

Doit définir :

- silhouette ;
- boîtier ;
- marquage ;
- bornes ;
- polarité/phase ;
- état UI ;
- état électrique ;
- défaut ;
- sélection ;
- compatibilité de câblage ;
- inactive/disabled ;
- zoom simplification ;
- palette vs canvas.

G1 ne dessine pas toutes les familles finales. Il définit un **contrat de rendu** applicable à G4.

#### 5.3.2 Reference Screens

Quatre frames obligatoires :

1. **Accueil — desktop 1440×900** ;
2. **Workspace — desktop 1440×900** ;
3. **Workspace — compact 390×844** ;
4. **Recherche de dérangement élève — 820×1180 ou 1440×900 selon la composition validée**.

Chaque frame est product-grade, pas wireframe.

## 6. Direction visuelle

### Caractère

- industriel ;
- pédagogique ;
- moderne ;
- précis ;
- professionnel ;
- clair en atelier ;
- sans esthétique gadget.

### Réalisme

Le rendu est **semi-technique fonctionnel** :

- plus riche qu’un rectangle générique ;
- moins détaillé qu’une photo ;
- bornes et fonctions prioritaires ;
- métaphores électriques reconnaissables ;
- détails décoratifs subordonnés à la lisibilité.

### Densité

L’objectif n’est pas une interface minimaliste vide. ElectroSim est un outil technique ; la densité doit être maîtrisée mais suffisante pour transmettre la richesse fonctionnelle.

## 7. Système de couleurs

### 7.1 UI sémantique

Figma doit définir au minimum :

- `ui/primary`;
- `ui/on-primary`;
- `ui/secondary`;
- `ui/background`;
- `ui/surface`;
- `ui/surface-raised`;
- `ui/surface-muted`;
- `ui/outline`;
- `ui/text-primary`;
- `ui/text-secondary`;
- `ui/text-disabled`;
- `ui/success`;
- `ui/warning`;
- `ui/danger`;
- `ui/info`;
- `ui/focus`.

### 7.2 Couleurs électriques

Doivent rester physiquement et conceptuellement séparées des couleurs UI :

- `electrical/dc-positive`;
- `electrical/dc-negative`;
- `electrical/l1`;
- `electrical/l2`;
- `electrical/l3`;
- `electrical/neutral`;
- `electrical/protective-earth`;
- états de potentiel ou énergie uniquement si justifiés.

Aucun état critique ne dépend uniquement de la couleur.

## 8. Typographie

Le système doit définir des styles fonctionnels, non des tailles isolées :

- Display ;
- Heading L/M/S ;
- Title L/M/S ;
- Body L/M/S ;
- Label L/M/S ;
- Technical value ;
- Technical unit ;
- Monospace/diagnostic si nécessaire.

Les valeurs finales sont décidées en Figma puis reflétées dans Flutter.

Exigences :

- chiffres et unités lisibles ;
- contrastes AA minimum ;
- échelle compatible avec text scaling ;
- aucune taille fixe provoquant overflow sur compact.

## 9. Espacement et géométrie

Échelle basée sur 4/8 px.

Les tokens actuels `4, 8, 12, 16, 24, 32` peuvent être conservés s’ils passent la revue Figma.

Doivent aussi être tokenisés :

- toolbar height ;
- control height ;
- compact control height ;
- panel width ;
- palette width ;
- inspector width ;
- status bar height ;
- minimum touch target ;
- terminal hit target ;
- icon sizes principales.

Les largeurs de panneaux restent adaptatives selon le window class.

## 10. Rayons et élévations

Les rayons sont limités pour conserver une identité technique.

Niveaux attendus :

- compact control ;
- card ;
- panel ;
- dialog.

Les ombres/élévations sont utilisées avec parcimonie ; la hiérarchie repose d’abord sur surfaces, contours et structure.

## 11. États interactifs

Chaque composant applicable doit documenter :

- default ;
- hover ;
- pressed ;
- focused ;
- selected ;
- disabled ;
- loading ;
- error.

Les composants Canvas ont en plus :

- dragging ;
- wire-source ;
- compatible target ;
- incompatible target.

Aucun de ces états UI ne doit signifier implicitement `energized`, `running` ou `faulted`.

## 12. Contrat visuel électrique

Chaque famille future G4 devra fournir un `VisualDescriptor` conceptuel avec :

- `modelType` canonique ;
- famille visuelle ;
- silhouette ;
- aspect ratio ;
- zones de marquage ;
- bornes ;
- labels de bornes ;
- états visuels ;
- simplification à petite échelle ;
- rotation supportée ;
- représentation palette ;
- représentation canvas.

### Règle de cohérence

Palette et canvas utilisent la **même identité de composant**. La palette peut réduire le niveau de détail, jamais changer de métaphore.

## 13. Accessibilité

G1 doit assurer :

- contraste WCAG AA minimum ;
- focus visible ;
- aucune information critique couleur-only ;
- labels sémantiques ;
- touch target ≥ 48 px pour actions tactiles principales ;
- text scaling sans clipping critique ;
- états hover non indispensables ;
- navigation clavier cohérente.

## 14. Responsive

Breakpoints Flutter actuels restent contractuels pendant G1 :

- compact : < 600 ;
- medium : 600–1000 ;
- expanded : > 1000.

Références obligatoires :

- 390×844 ;
- 820×1180 ;
- 1440×900 ;
- 1920×1080 pour vérification, même sans frame Figma dédiée si extrapolation documentée.

Règle principale : **le Canvas ne doit jamais devenir secondaire ou inaccessible sur compact**.

## 15. Screens de référence

### 15.1 Accueil desktop

Doit montrer :

- marque ElectroSim ;
- création de session ;
- centre maintenance ;
- centre conception ;
- rejoindre session comme action secondaire ;
- hiérarchie claire ;
- densité maîtrisée.

### 15.2 Workspace desktop

Doit montrer simultanément :

- top bar ;
- palette ;
- canvas ;
- inspecteur ;
- status bar ;
- états de sélection ;
- quelques composants électriques réalistes de démonstration.

Il ne doit pas être confondu avec l’implémentation finale G4 du catalogue.

### 15.3 Workspace compact

Doit préserver :

- Canvas dominant ;
- accès rapide palette ;
- accès inspecteur ;
- top bar condensée ;
- actions essentielles ;
- zéro clipping.

### 15.4 Recherche de dérangement élève

Doit montrer :

- Canvas ;
- fiche diagnostic déployable ;
- absence d’EIE coach ;
- progression pédagogique ;
- état avant réparation ;
- séparation claire mesures/diagnostic/réparation.

## 16. Mapping Figma → Flutter

Chaque token Figma doit avoir une correspondance documentée.

Exemple de convention :

| Figma | Flutter |
|---|---|
| `ui/primary` | `ElectroSimColors.primary` |
| `space/16` | `ElectroSimSpacing.md` |
| `radius/card` | `ElectroSimRadii.card` |
| `geometry/touch-target` | `ElectroSimGeometry.minimumTouchTarget` |

Le fichier de mapping doit être machine-lisible en G1.

Aucune valeur Flutter ne peut être déclarée conforme si elle n’a pas de source Figma ou d’exception documentée.

## 17. Architecture Flutter G1

G1 intervient uniquement dans `packages/electrosim_ui_kit` et les tests/outils associés.

Fichiers existants susceptibles d’être modifiés :

- `lib/src/design_tokens.dart`;
- `lib/src/electrosim_theme.dart`;
- `lib/src/responsive.dart`;
- `test/design_system_test.dart`.

Nouveaux fichiers possibles :

- `lib/src/typography_tokens.dart`;
- `lib/src/component_tokens.dart`;
- `lib/src/electrical_visual_tokens.dart`;
- `test/token_mapping_test.dart`;
- outils de validation dans `tools/f18_g1_*`.

Le plan d’implémentation décidera les fichiers finaux ; cette liste n’autorise pas un refactor hors périmètre.

## 18. Figma comme source de vérité

Le fichier Figma produit par G1 devient la source de vérité visuelle.

Règles :

1. aucune mise à jour de golden sans référence Figma correspondante ;
2. tout changement visuel significatif commence par Figma ou par une exception approuvée et documentée ;
3. tokens Flutter générés/manuellement synchronisés doivent être vérifiés ;
4. les frames de référence doivent avoir un identifiant stable enregistré dans Git.

## 19. Gestion de la permission Figma

Le connecteur Figma est actif. Le fichier G1 a pu être créé sur le plan Starter, qui impose toutefois une limite de trois pages et un quota MCP. La structure G1 est donc volontairement adaptée à trois pages physiques sans réduire son contenu.

Le workflow G1 doit :

1. tenter proprement la création ou l’édition après approbation de la présente spec ;
2. utiliser exactement trois pages : `00 Foundations`, `01 Components`, `02 Electrical System` ;
3. si l’écriture ou le quota MCP bloque l’opération, arrêter uniquement le sous-gate Figma ;
4. ne pas contourner Figma en déclarant arbitrairement le code comme source visuelle ;
5. demander à l’utilisateur uniquement l’action minimale nécessaire si une permission ou capacité externe manque ;
6. reprendre ensuite sur le même plan.

Une limitation de siège n’autorise pas à dégrader la méthodologie.

## 20. Politique de goldens

G1 prépare la transition vers une politique plus stricte.

Un golden valide doit avoir :

- référence Figma ;
- taille de viewport ;
- état d’UI identifié ;
- nom stable ;
- diff visuel en CI si échec.

Interdit :

- auto-accept CI ;
- remplacement massif de goldens sans revue ;
- accepter un diff uniquement parce qu’il correspond au code actuel.

## 21. Gate G1

Le gate G1 doit vérifier au minimum :

- source Figma enregistrée ;
- mapping tokens Figma↔Flutter complet ;
- aucune valeur requise sans mapping ;
- tests unitaires des tokens ;
- tests contrastes ;
- tests text scaling ;
- breakpoints inchangés sauf décision explicite ;
- `flutter analyze` ;
- tests `electrosim_ui_kit` ;
- suite application de non-régression ;
- aucun fichier moteur/solver/runtime modifié.

Marqueur attendu :

`F18_G1_DESIGN_SYSTEM_GATE_PASS`

## 22. Livrables G1

- fichier Figma G1 ;
- identifiant/url Figma enregistré dans Git ;
- export ou metadata de référence si nécessaire ;
- document de mapping tokens ;
- tokens Flutter ;
- tests UI kit ;
- gate GitHub Actions ;
- screenshots/goldens de référence ;
- rapport G1 ;
- ledger d’exécution.

## 23. Risques et contrôles

### Risque : Figma devient décoratif

Contrôle : mapping obligatoire et gate machine-lisible.

### Risque : design incompatible avec Flutter

Contrôle : écran de référence limité à quatre vues et implémentation des tokens avant G2.

### Risque : dérive moteur

Contrôle : allowlist stricte de fichiers G1 et diff guard.

### Risque : surdesign

Contrôle : composants fondamentaux seulement, catalogue détaillé repoussé à G4.

### Risque : goldens qui légitiment une mauvaise UI

Contrôle : aucun golden nouveau sans frame Figma correspondante.

### Risque : permissions Figma

Contrôle : sous-gate explicite, arrêt propre, pas de contournement.

## 24. Critères de sortie G1

G1 est terminé uniquement si :

1. Foundations Figma complètes ;
2. Components fondamentaux complets ;
3. Electrical Visual Language documenté ;
4. quatre Reference Screens approuvés ;
5. mapping Figma↔Flutter complet ;
6. tokens Flutter synchronisés ;
7. contraste/accessibilité de base verts ;
8. tests UI kit verts ;
9. suite app sans régression ;
10. moteur/runtime inchangé ;
11. gate exact-head vert ;
12. aucune finding Critique ou Importante ouverte.

## 25. Ce que G1 autorise ensuite

Après fusion G1 :

- G2 peut reconstruire le shell/navigation sur des primitives visuelles validées ;
- G3 peut reconstruire le workspace responsive ;
- G4 peut implémenter les 20 familles visuelles critiques sur le contrat électrique défini ici.

G1 ne constitue pas à lui seul une refonte visible complète d’ElectroSim.

## 26. Références

- `docs/superpowers/specs/2026-09-30-electrosim-f18-product-parity-design.md`
- `docs/f18/g0/F18_G0_REPORT.md`
- `docs/f18/g0/F18_PRODUCT_PARITY.csv`
- `docs/f18/g0/F18_CAPABILITY_PARITY.csv`
- `docs/f9/F9_COMPONENT_VISUAL_LANGUAGE.md`
- `docs/f9/F9_COMPONENT_RENDER_CONTRACT.md`
- `docs/f9/F9_ACCESSIBILITY_AND_INPUT_SPEC.md`
- `packages/electrosim_ui_kit/lib/src/design_tokens.dart`
- `packages/electrosim_ui_kit/lib/src/electrosim_theme.dart`
- `packages/electrosim_ui_kit/lib/src/responsive.dart`
