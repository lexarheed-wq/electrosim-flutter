# F18 — Audit UI/UX statique pré-G2/G3

**Base auditée :** `main@591b8d6386de36093ed22deaab785c38245f5331`  
**Nature :** lecture seule du code Flutter actuel. Aucun code produit n'est modifié par cet audit.

## Résumé

L'architecture moteur F17 n'est pas remise en cause. Les écarts sont concentrés dans la **couche produit** : shell, palette, Canvas visuel, actions de platine, rôles professeur/élève et gouvernance des tokens.

La matrice détaillée contient **20 écarts** :
- **10 Important**
- **10 Moderate**
- **0 Critical**

Le point principal est structurel : `main.dart` reste un shell de qualification F9 devenu application de fait. Il porte encore le nom `F9WorkspaceDemoPage`, injecte un circuit de démonstration par défaut et concentre plusieurs responsabilités qui devront être séparées en G2/G3.

## Écarts prioritaires avant reconstruction

### 1. Shell encore orienté démonstrateur

`F9WorkspaceDemoPage` est utilisé par les entrées produit et initialise `_buildDemoCircuit()` lorsqu'aucun circuit n'est fourni. Le Centre de conception n'ouvre donc pas un vrai contexte produit neutre par contrat. Le statut initial expose aussi « F9 final — interface responsive et Canvas F8 validé ».

**Traitement : G2/G3.** Renommer/recomposer le shell, définir explicitement l'état initial selon l'entrée et supprimer toute copie de jalon interne visible.

### 2. Actions de platine non conformes à la cible F18

La top bar actuelle contient Accueil, Tableau de bord, gestion session, sauvegarde/reprise, badge Accès direct et recentrage. Elle ne contient ni Supprimer ni Rotation. L'action Supprimer reste dans le panneau Propriétés.

**Traitement : G3/G6.** Un seul Supprimer en haut de platine, Rotation à proximité, aucune duplication dans Propriétés.

### 3. Sélection multiple absente

Le Canvas et le workspace transportent un seul `String?` sélectionné. Aucun chemin Ctrl/Cmd/Shift n'est présent.

**Traitement : G6.** Sélection simple par défaut, multi-sélection seulement avec modificateur, clic fond pour effacer.

### 4. Deux autorités d'interaction Canvas

`SimulatorCanvas` contient son propre GestureDetector et sa logique de sélection/drag/zoom, mais l'application le monte avec `enableInteraction: false` puis lui superpose une seconde couche d'interactions dans `main.dart`.

**Traitement : G6.** Définir une seule autorité pour les gestes et le câblage avant toute nouvelle UX Canvas.

### 5. Palette encore F9

La palette contient 12 définitions, affiche 6 accès rapides, et sa recherche est un simple `lowercase.contains`. Le sous-titre utilisateur affiche « Palette F9 finale ».

**Traitement : G5.** 5 accès rapides/domaines, recherche accent/synonyme/multi-mots, catalogue uniquement pour familles réellement supportées.

### 6. Design tokens incomplets

Le UI kit possède déjà de bons points d'ancrage (`ElectroSimColors`, spacing, radii, geometry), mais des couleurs et dimensions sont encore codées localement dans la palette, le shell et surtout `CircuitScenePainter`.

**Traitement : G1 puis G4/G6.** Figma devient source de vérité et le Canvas consomme les mêmes tokens électriques/sémantiques.

### 7. Rôles EIE/élève à corriger

`F9ContextPanels` affiche toujours Propriétés, Mesures et EIE. Le rôle élève ne change que l'ajout de Diagnostic. L'élève voit donc encore l'EIE technique.

**Traitement : G8/G10.** EIE technique professeur uniquement ; élève RD = fiche diagnostic sans coach/EIE technique.

### 8. Accessibilité Canvas insuffisante

Le Canvas expose une Semantics globale, mais pas d'éléments navigables pour composants, bornes ou connexions.

**Traitement : G11**, après stabilisation de l'architecture G6 afin d'éviter de construire deux fois la couche sémantique.

## Comportements actuels à préserver

Plusieurs choix sont déjà alignés avec F18 et ne doivent pas régresser :

- **Centre de conception → Câblage direct** et **Centre de maintenance → Recherche de dérangement direct**.
- La fiche Diagnostic n'apparaît que pour le rôle élève en Recherche de dérangement.
- Le contrôleur TP dispose d'un état lecture seule côté élève après remise.
- Le shell possède déjà trois classes responsive compact / medium / expanded.
- Les mesures affichées sont alimentées par le runtime/MeasurementEngine ; l'UI ne doit jamais recalculer l'électricité.
- Les couleurs électriques sont conceptuellement séparées des couleurs UI dans `electrosim_ui_kit`.
- Les actions principales Material disposent généralement de tooltips/touch targets ; ces acquis doivent être conservés lors de la refonte.

## Séquencement recommandé

1. **G1** : tokens Figma↔Flutter, suppression des couleurs/dimensions visuelles orphelines au niveau design system.
2. **G2** : nouveau shell/navigation et suppression des concepts « Demo/F9 » visibles.
3. **G3** : workspace responsive, top/status bars et panneaux contextuels.
4. **G4/G5** : langage visuel électrique et palette/catalogue.
5. **G6** : autorité d'interaction Canvas, sélection multiple, actions Supprimer/Rotation, câblage.
6. **G8/G10** : rôles TP et EIE.
7. **G11** : accessibilité, text scaling et polish.

Le détail normatif est dans `F18_UI_UX_GAP_MATRIX.csv`.
