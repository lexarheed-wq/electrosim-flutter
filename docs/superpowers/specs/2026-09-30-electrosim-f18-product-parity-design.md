# ElectroSim F18 - Parité produit V1 → Flutter

**Date :** 30 septembre 2026  
**Base technique :** `ELECTROSIM2-F17-R12-QUALIFIED`  
**Référence produit :** ElectroSim V1 / FIELDFIX01-R1  
**Statut :** spécification écrite Superpowers - revue utilisateur requise avant plan d'implémentation.

> Objectif : conserver le noyau Flutter F17 qualifié, reconstruire la couche produit jusqu'à égaler au minimum la richesse utile de la V1, puis la dépasser en clarté, cohérence, interactivité, robustesse et qualité visuelle.

## 1. Résumé exécutif

F17 a qualifié le noyau technique : topologie, solveurs CC/AC/PV, mesures, diagnostics, TP, persistance, synchronisation LAN et builds natifs. Cette qualification ne signifie pas que la couche produit visible a atteint la maturité de la V1.

La comparaison physique du 30/09/2026 montre un écart net de densité fonctionnelle, identité visuelle, différenciation des composants, richesse de la palette et maturité des parcours. La V1 documente 103 familles actives de composants, alors que le Flutter actuel reste visuellement centré sur un shell F9 et un circuit de démonstration très réduit.

F18 traite exclusivement cette dette produit sans réintroduire l'architecture JavaScript historique.

## 2. Sources de vérité

1. Les décisions utilisateur les plus récentes priment.
2. Le présent cahier des charges est le contrat produit F18.
3. Les contrats et tests F17 qualifiés sont protégés.
4. La V1 est une référence minimale de maturité et d'ergonomie.
5. Le code V1 est un oracle d'investigation uniquement ; aucune dépendance runtime Flutter n'est autorisée.

## 3. Principes non négociables

- L'UI ne calcule jamais tension, courant, puissance, énergie ou état électrique.
- Aucun composant décoratif ne peut être proposé comme simulable sans modèle moteur réel.
- Une famille possède une identité visuelle cohérente palette ↔ platine ↔ propriétés.
- La simplification réduit le bruit, pas la puissance fonctionnelle.
- Les packages cœur F17 restent protégés.
- EIE est interne, silencieux quand tout va bien et explicable sur anomalie.
- Toute évolution doit être réversible par branche, commit et preuve de test.
- Aucun golden n'est auto-accepté par CI.

## 4. Périmètre F18

### Inclus
- Accueil, navigation, centres maintenance/conception, création/gestion session.
- Workspace complet : top bar, palette, canvas, propriétés, mesures, EIE, status.
- Design system Figma → Flutter.
- Système visuel des composants et conducteurs.
- Reconstruction progressive du catalogue utile V1.
- Instruments et UX CC/AC1/AC3/PV.
- Bibliothèques neuves de schémas sains et de pannes autonomes.
- Parcours professeur/élève, diagnostic, réparation, notation, clôture.
- Supervision et gestion des activités.
- Responsive, accessibilité, performance et qualification native.

### Exclus sauf défaut bloquant
- Réécriture des solveurs F17.
- Migration directe du JavaScript historique.
- Import automatique des schémas/pannes V1.
- Ajout de familles non modélisées uniquement pour enrichir visuellement la palette.

## 5. Navigation cible

### Accueil
- **Créer une nouvelle session** → préparation professeur, puis accès Accueil / Tableau de bord / Gérer la session.
- **Centre de maintenance** → Recherche de dérangement + bibliothèque de pannes.
- **Centre de conception** → Câblage + bibliothèque de schémas sains.
- Aucun écran ne doit redemander inutilement Câblage/RD après le choix du centre.

### Session
- Barre stable : Accueil, Tableau de bord, Gérer la session.
- Tableau de bord : Câblage, Recherche de dérangement, Supervision.
- Gérer la session : publication, participants, code/adresse LAN, arrêt et état de synchronisation.
- Chaque bouton de navigation possède un test de destination.

## 6. Design system Figma → Flutter

Figma devient la source de vérité visuelle. Les références golden Flutter sont dérivées des frames Figma approuvées, pas de l'état courant de l'application.

### Tokens requis
- couleurs de surface, texte, primaire, domaine, succès, avertissement, défaut ;
- typographie titres/corps/labels/valeurs techniques ;
- grille 4/8 px ;
- rayons et élévations limités ;
- états hover/focus/sélection/drag/alimenté/actif/défaut/désactivé.

### Direction
- style industriel pédagogique moderne ;
- composants semi-réalistes techniques ;
- bornes/connectique prioritaires ;
- couleurs électriques normalisées et configurables ;
- animations brèves et informatives seulement ;
- mode clair prioritaire pour l'atelier.

## 7. Workspace produit

Le shell F9 de démonstration doit être remplacé par un scaffold produit stable.

Zones :
- **Top bar** : navigation, édition/simulation, domaine, actions principales.
- **Palette** : recherche, 4-5 rapides, catégories, catalogue complet.
- **Canvas** : platine, composants, fils, repères, overlays.
- **Inspecteur** : Propriétés, Mesures, EIE.
- **Status bar** : domaine, éléments, source, révision, session/LAN.

### Sélection
- clic/tap simple ;
- multi-sélection uniquement avec modificateur ;
- clic fond = désélection ;
- un seul bouton Supprimer en haut, instruments inclus ;
- Rotation à côté de Supprimer ;
- aucun doublon Supprimer dans Propriétés.

## 8. Système visuel des composants

Chaque famille possède un `VisualDescriptor` partagé :
- modelType canonique ;
- nom court et pédagogique ;
- domaines ;
- visuel palette ;
- rendu canvas ;
- positions/libellés de bornes ;
- états visuels ;
- icône compacte ;
- paramètres exposés ;
- règles d'échelle/rotation.

Barre minimale :
- deux familles fonctionnellement différentes ne partagent pas le même bloc générique ;
- reconnaissance visuelle sans dépendre systématiquement du texte ;
- bornes visibles conformes au contrat ;
- états actif/inactif/défaut distincts ;
- même identité palette/canvas.

## 9. Catalogue, palette et recherche

La V1 documente **103 familles actives** dans B4-RC10. F18 construit une matrice exhaustive :

- **REBUILD** : modèle F17 disponible/réalisable sans rupture.
- **REPLACE** : fonction conservée mais UX/modèle remplacé.
- **DEFER** : nouveau modèle moteur requis ; invisible en production.
- **RETIRE** : fonction obsolète/redondante avec justification.

Palette cible :
- 5 accès rapides par domaine ;
- recherche tolérante accents/synonymes/mots multiples ;
- compteur et catégories ;
- Voir tous fiable en un clic ;
- restrictions pédagogiques élève prioritaires.

## 10. Canvas et câblage

- Pan desktop + trackpad deux doigts.
- Zoom molette/raccourcis + pinch.
- Drag direct des composants.
- Câblage borne→borne avec hit-test fiable.
- Routage orthogonal stable.
- Profils couleurs CC/AC1/AC3.
- AUTO/MANUAL conservé.
- Halo électrique superposé à la couleur physique.
- Aucun terminal masqué.
- Aucun fil ne traverse un composant sans nécessité.

## 11. Instruments et mesures

- Voltmètre, ampèremètre, continuité, fréquence, phase order et instruments PV uniquement si MeasurementEngine les supporte.
- Valeurs exclusivement issues de SimulationResult/MeasurementEngine.
- NON RACCORDÉ explicite si nécessaire.
- Suppression commune avec les autres éléments.
- Ne pas réintroduire les anciens blocages « hors tension / sous tension ».

## 12. Domaines

- **CC** : sources, protections, récepteurs, mesures CC.
- **AC1** : L/N/PE, protections, fréquence, récepteurs.
- **AC3** : L1/L2/L3/N/PE explicites, contacteurs, relais thermiques, moteurs.
- **PV** : panneau, irradiance/température/ombrage, régulateur, batterie, onduleur, énergie.

Aucune approximation inter-domaines n'est autorisée.

## 13. Bibliothèques neuves

- **Schémas sains** : circuits complètement câblés et fonctionnels.
- **Pannes** : scénarios autonomes déjà défectueux.
- Aucun `exampleId` dans les pannes.
- Teacher truth séparé et jamais exposé dans le payload élève.
- Chaque item : objectif, domaine, difficulté, matériel, résultat attendu, signature déterministe.
- La release F18 exige une matrice de couverture pédagogique, pas un simple nombre d'items.

## 14. Professeur / élève / TP

### Professeur
- créer, modifier, publier, supprimer ;
- choisir Câblage/RD sans navigation redondante ;
- supervision progression/statut/résultat/note ;
- notation RD ;
- accès EIE technique.

### Élève
- fiche diagnostic uniquement dans le simulateur RD ;
- réparation déverrouillée après diagnostic validé ;
- aucun coach EIE ;
- TP terminé = lecture seule + résultats ;
- mobile sans zones inaccessibles.

## 15. EIE

- surveillance solver, incohérences physiques, conflits, régressions et dérive architecture ;
- silence si OK ;
- notification seulement sur anomalie utile ;
- détails techniques cachés par défaut ;
- aucune cause inventée ;
- aucune modification automatique du circuit/solver.

## 16. Persistance et LAN

### Persistance
- sauvegarde/reprise explicites, atomiques, versionnées ;
- cycle TP reconstruit par transitions validées ;
- corruption visible et récupérable.

### LAN
- professeur affiche adresse complète copiable + code 6 caractères ;
- élève accepte adresse complète et formes ergonomiques documentées ;
- normalisation avant validation ;
- erreur format distincte de l'erreur connexion ;
- reconnexion avec rattrapage état professeur ;
- tests loopback + validation physique réseau local.

## 17. Responsive et accessibilité

Références :
- compact 390×844 ;
- medium 820×1180 ;
- desktop 1440×900 ;
- large 1920×1080.

Exigences :
- zéro clipping/panneau inaccessible ;
- focus visible ;
- ordre clavier logique ;
- actions principales clavier ;
- labels sémantiques ;
- contraste WCAG AA minimum ;
- touch targets adaptés ;
- VoiceOver ciblé sur accueil, palette, canvas, diagnostic, supervision.

## 18. Budgets performance

- démarrage chaud Mac cible ≤ 5 s ;
- recherche ~100 familles ≤ 100 ms perçus ;
- pan/zoom 100 composants / 150 fils ≥ 55 fps moyen, sans gel ;
- latence drag p95 < 35 ms ;
- changement onglet/propriétés ≤ 150 ms perçus ;
- sauvegarde scénario moyen ≤ 1 s.

Tout dépassement doit être mesuré et documenté, jamais ignoré.

## 19. Architecture F18

### Noyau protégé
Packages considérés protégés :
`domain`, `topology`, `solver_dc`, `solver_ac`, `pv`, `energy`, `measurements`, `diagnostics`, `tp`, `storage`.

Toute modification exige :
1. test rouge reproduisant le besoin ;
2. contrat documenté ;
3. gate moteur dédié ;
4. régression complète.

### Couche produit
- remplacer progressivement les noms/classes F9 de production ;
- modules : home, session, design, maintenance, workspace, palette, inspector, supervision, libraries ;
- interfaces étroites UI/runtime ;
- aucune dépendance runtime vers V1 ;
- transformations UI↔domaine testées.

## 20. Stratégie de tests

- unitaires ;
- widgets ;
- goldens ;
- intégration runtime ;
- property/fuzz ciblé ;
- performance ;
- builds release Linux/Windows/Android/macOS/iOS ;
- validation physique Mac.

### Goldens
- jamais d'auto-acceptation CI ;
- baseline + candidate + diff en cas d'écart ;
- mise à jour seulement avec justification Figma/correction ;
- états vides, erreur, chargement, sélection, défaut, responsive couverts.

## 21. Méthodologie autonome Superpowers + GitHub

Après approbation de cette spécification, F18 est exécuté comme **programme de gates indépendants** et non comme un changement monolithique. Chaque gate G0→G12 possède son propre plan, sa branche/worktree, ses tests, ses preuves et sa PR. Un gate ne démarre qu'après qualification du précédent sur la base intégrée.

1. écrire le plan directeur F18 puis le plan détaillé du gate courant dans `docs/superpowers/plans/` ;
2. créer un worktree/branche isolé depuis `main` vert ;
3. TDD systématique rouge → vert → refactor ;
4. petits commits vérifiables ;
5. tests ciblés puis régression ;
6. preuves : captures, goldens, JSON, logs, SHA ;
7. revue de code après chaque lot majeur et avant fusion ;
8. aucun merge si un gate échoue ;
9. `main` reste stable et rollbackable.
10. aucun gate n'est fusionné avec des findings Critiques ou Importants ouverts ; les findings Mineurs sont explicitement tracés.
11. les validations physiques sont demandées uniquement quand un comportement matériel ne peut pas être qualifié de façon fiable en CI.

Outils :
- **Superpowers** : brainstorming, planning, TDD, debugging, review, verification ;
- **GitHub** : branches, Actions, PR, artefacts, rollback ;
- **Figma** : design system, frames de référence, tokens/composants ;
- **Flutter/Dart verrouillé** : tests, profiling, builds ;
- **scripts de qualification** : diffs, manifestes, SHA, gates.

## 22. Roadmap F18

| Gate | Objet | Critère de sortie |
|---|---|---|
| G0 | baseline & inventaire | matrice V1 complète, main F17 figé |
| G1 | design system Figma | tokens + frames référence complets |
| G2 | product shell/navigation | routes testées, plus de shell demo |
| G3 | workspace scaffold | goldens 4 tailles, zéro clipping |
| G4 | visual framework | 20 familles critiques cohérentes |
| G5 | catalogue parité | toutes familles supportées traitées |
| G6 | canvas & câblage | gestes, routage, couleurs, perf verts |
| G7 | instruments/propriétés | mesures réelles, UX complète |
| G8 | TP professeur/élève | cycle complet + lecture seule |
| G9 | bibliothèques | couverture pédagogique documentée |
| G10 | EIE produit | surface teacher + silence si OK |
| G11 | polish qualité | a11y + responsive + perf verts |
| G12 | qualification finale | 5 releases + `F18_PHYSICAL_MAC_PASS` |

## 23. Risques majeurs

- **Régression solveur** → noyau protégé + contrats.
- **Golden update qui masque une régression** → aucune auto-acceptation.
- **Catalogue décoratif** → audit modelType ↔ solver.
- **Explosion complexité UI** → modules bornés + design system + YAGNI.
- **Performance canvas** → benchmarks dès G4/G6.
- **Copie aveugle de V1** → V1 = référence qualité, pas architecture.
- **Différences plateforme** → toolchain verrouillée + artefacts.
- **Erreur Mac tardive** → simulation gestes + gate physique court.

## 24. Definition of Done F18

F18 n'est terminé que si :
- G0 à G12 PASS sur le même head ;
- matrice de parité sans item utile/supporté non traité ;
- chaque écran de production possède une référence Figma + golden ;
- aucun composant décoratif non simulable ;
- parcours professeur/élève complets ;
- budgets perf/a11y/responsive documentés ;
- 5 builds release natifs + SHA-256 ;
- `F18_PHYSICAL_MAC_PASS` ;
- aucune finding critique/importante ouverte en revue ;
- fusion main seulement après preuve complète.

## 25. Décisions déjà validées à conserver

- 3 entrées accueil ;
- maintenance → RD/pannes ; conception → câblage/schémas sains ;
- fiche diagnostic uniquement élève RD ;
- réparation après diagnostic validé ;
- coach étudiant supprimé ;
- EIE interne ;
- composants réalistes/cohérents palette/platine ;
- 4-5 rapides + recherche + voir tous fiable ;
- Supprimer unique en haut + Rotation voisine ;
- multi-sélection avec modificateur seulement ;
- pas de réintroduction de la complexité hors tension/sous tension ;
- TP terminé lecture seule ;
- professeur peut supprimer/publier et noter les TP RD.

## 26. Références

- `docs/f17/STATUS.md`
- `docs/f17/R12_RELEASE_QUALIFICATION.md`
- `apps/electrosim/lib/main.dart`
- `README_F16_R1.md`
- V1 `BIBLIOTHEQUE_COMPOSANTS_B4_RC10.md`
- V1 `PALETTE01_COMPACT_COMPONENT_SEARCH_REPORT.md`
- vidéo physique Flutter F17 du 30/09/2026
