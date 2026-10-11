# Professional ElectroSim Workspace — Phase A Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Native execution is recommended; the user must confirm the plan and execution method before implementation.

**Goal:** Livrer un atelier clair et utilisable, avec commandes permanentes, panneaux adaptatifs, transitions accessibles et conservation du câblage existant.

**Architecture:** Le UI kit compose la disposition sans connaître le circuit. Un contrôleur de disposition pilote les tailles et la visibilité ; l’application raccorde sa persistance et adapte le viewport du circuit lors des changements de taille. Les changements de présentation ne déclenchent aucun calcul électrique ou reroutage global.

**Tech Stack:** Flutter 3.38.10, Dart 3.10.9 ; packages locaux ElectroSim ; `path_provider` existant pour les préférences natives. Aucune nouvelle bibliothèque nécessaire.

**Spec:** `docs/superpowers/specs/2026-10-08-professional-workspace-design.md`.

## Global Constraints

- Base : `09f0459dd584c6231870387e7d5f8d8dd77b647d`, corrections de performance conservées.
- Grand écran : au moins 1200 px ; intermédiaire : 720 à 1199 px ; compact : moins de 720 px. Classification spécifique à l’atelier, sans modifier les breakpoints historiques de l’accueil.
- Palette 264 px par défaut, bornes 220–360 ; inspecteur 304 px, bornes 280–440 ; canvas desktop minimum 480 px, séparateurs compris.
- Barres : hauteur minimale supérieure 64 px desktop / 56 px compacte ; statut 40 px minimum, extensibles au texte.
- Cibles tactiles 48×48 px ; texte testé à 150 % et 200 % ; respect de `MediaQuery.disableAnimations`.
- Transitions de panneau 200 ms, dans l’intervalle 180–220 ms de la spécification ; aucun rebond ni temporisation au survol.
- Aucune modification du moteur, du schéma des sauvegardes de circuit ou des droits élève. Pas de commandes fictives Schéma/Annuler/Favoris.
- Ne pas faire passer une représentation de maquette ou une valeur illustrative pour une mesure moteur.

## Review Focus

- Fenêtre réduite pendant un câblage : annuler proprement le geste, ne pas connecter un ancien point écran ; test tâche 4.
- Panneaux redimensionnés au maximum à 1200 px : préserver la zone centrale ou basculer vers un seul panneau ; test tâche 2.
- Préférences corrompues ou écriture refusée : l’atelier reste utilisable et aucune exception non traitée ; test tâche 3.
- Navigation rapide pendant une animation : aucun callback après destruction, focus rendu au bon contrôle ; test tâche 2.
- Texte 200 % et droits élève : tous les contrôles utiles restent accessibles sans activer une action interdite ; test tâche 5.

## Scope

Ce plan réalise le lot A uniquement. Les commandes mécaniques et le retour visuel des bornes appartiennent au lot B ; l’historique, les favoris et la représentation schématique au lot C. Chacun nécessite un plan distinct. Le volet inférieur de résultats détaillés sera traité avec le lot C ; le statut actuel reste visible dans A. Cette séparation ne vaut pas achèvement de toute la refonte.

## File Structure

- Créer `packages/electrosim_ui_kit/lib/src/workspace_layout_controller.dart` : état et validation de la disposition, sans IO ni circuit.
- Modifier `packages/electrosim_ui_kit/lib/src/workspace_shell.dart` : composition responsive et contrôles des panneaux.
- Créer `packages/electrosim_ui_kit/lib/src/workspace_resize_handle.dart` : séparateur avec souris, clavier et sémantique.
- Modifier `packages/electrosim_ui_kit/lib/src/design_tokens.dart`, `electrosim_theme.dart` et `packages/electrosim_ui_kit/lib/electrosim_ui_kit.dart` : tokens/chrome et exports publics.
- Créer `apps/electrosim/lib/runtime/workspace_layout_preferences.dart` : préférences natives isolées, écritures sérialisées.
- Modifier `packages/electrosim_canvas/lib/src/viewport_controller.dart` : conservation du centre visible.
- Modifier `apps/electrosim/lib/main.dart`, `f9_component_palette.dart`, `f9_context_panels.dart` : raccordement, barre et formulaires.
- Créer les tests ciblés décrits ci-dessous et mettre à jour les contrats d’overlay devenus obsolètes.

## Execution environment

Pour les commandes Flutter : ajouter `/workspace/toolchains/flutter/bin` au PATH, `PUB_CACHE=/workspace/toolchains/pub-cache`, `XDG_CONFIG_HOME=/workspace/toolchains/config`, `FLUTTER_SUPPRESS_ANALYTICS=true`. Exécuter chaque commande depuis le package indiqué. Les tests Flutter demandent l’accès loopback. Le worktree d’exécution sera préparé avec le skill `using-git-worktrees` après revue de ce plan.

### Task 1: Contrôleur de disposition et tokens

**Files:** créer contrôleur et `packages/electrosim_ui_kit/test/workspace_layout_controller_test.dart` ; modifier tokens et export public.

**Interfaces:**
- `enum ElectroSimWorkspaceLayoutClass { compact, medium, expanded }` ; `ElectroSimWorkspaceLayoutClass classifyWorkspaceWidth(double width)` avec seuils 720/1200.
- `WorkspaceLayoutController extends ChangeNotifier`, constructeur sans argument ; getters `double paletteWidth`, `double contextWidth`, `bool paletteVisible`, `bool contextVisible`.
- Méthodes `void setPaletteWidth(double value)`, `void setContextWidth(double value)`, `void setPanelVisible(ElectroSimWorkspacePanel panel, bool visible)`, `Map<String, Object?> toJson()`, `void restore(Map<String, Object?> json)` ; les panneaux top/status restent permanents et ne sont pas masquables par ces méthodes.
- JSON version 1 : `version`, `paletteWidth`, `contextWidth`, `paletteVisible`, `contextVisible`. Refuser NaN/infini/types invalides ; version inconnue => valeurs par défaut ; champs valides bornés.
- Tokens nouveaux `workspaceHeader`, `workspaceOnHeader`, `workspaceAccent`, `workspaceDivider` ; ne pas modifier les tokens électriques.

- [ ] Écrire les tests de defaults 264/304, limites 220/360 et 280/440, non-finis, roundtrip JSON et version inconnue. Assertions : `expect(controller.paletteWidth, 264)` ; après `setPaletteWidth(999)`, `expect(controller.paletteWidth, 360)` ; version 999 restaure defaults.
- [ ] Lancer `flutter test test/workspace_layout_controller_test.dart` dans `packages/electrosim_ui_kit` : échec attendu, API absente.
- [ ] Implémenter API, tokens et export. Notifications uniquement si une valeur change ; pas de IO.
- [ ] Relancer tests ciblés et `test/f18_g1_token_contract_test.dart` : succès ; couleurs électriques inchangées.
- [ ] Commit `feat(ui): add validated workspace layout state and visual tokens`.

### Task 2: Coque ancrée, responsive et animée

**Files:** modifier shell ; créer séparateur et `packages/electrosim_ui_kit/test/professional_workspace_shell_test.dart` ; adapter `test/design_system_test.dart`.

**Interfaces:**
- Ajouter au constructeur existant `WorkspaceLayoutController? layoutController`, `bool interactionLocked = false`, `VoidCallback? onBeforeLayoutChange`, `ValueChanged<Size>? onCanvasSizeChanged`. Contrôleur interne si non injecté, détruit uniquement s’il appartient au shell.
- `WorkspaceResizeHandle({required Axis axis, required ValueChanged<double> onDelta, required String semanticLabel, required bool enabled})` : delta écran, pas absolu ; flèches ±8 px, sémantique augmenter/diminuer ; surface tactile 48 px superposée à un trait visuel fin.
- Conserver clés de régions existantes. Les clés des poignées de bord désignent désormais les boutons visibles d’ouverture ; garder les helpers de test compatibles quand possible. Top/status n’ont plus d’épinglage.
- Fermeture compacte retire hit-test et focus immédiatement ; retour au bouton déclencheur ; Esc/retour ferme le panneau avant quitter la page.

- [ ] Écrire tests harness avec contenu simple : à 1440×900, rectangles palette/context/canvas disjoints, barres visibles ; déplacer un séparateur modifie largeur et pas top/status ; aucun auto-close après 500 ms.
- [ ] Ajouter tests 390×844 et 820×1180 : palette puis propriétés => un panneau atteignable ; fermeture par Esc rend focus ; cibles tactiles et libellés passent.
- [ ] Ajouter tests 1200 px, largeurs maximales : canvas ≥480 ou disposition medium exclusive ; bascule large/compact restaure l’état desktop sans ouvrir deux panneaux compacts.
- [ ] Ajouter tests animations désactivées, widget retiré pendant une transition et `interactionLocked=true` : pas d’exception, pas de drag de séparateur actif.
- [ ] Lancer `flutter test test/professional_workspace_shell_test.dart` dans UI kit : échecs comportementaux attendus.
- [ ] Implémenter shell avec colonne barres/corps/statut, régions ancrées et séparateurs ; transition 200 ms `easeOutCubic`, durée nulle si réduction activée ; éviter reconstruction du canvas fourni en tant que child stable.
- [ ] Notifier la taille réelle du canvas après layout, uniquement si elle change ; invalider le callback après dispose. Préparer/annuler le geste avant les changements explicites de disposition.
- [ ] Mettre à jour uniquement les tests qui imposent fullscreen/autohide ; lancer `flutter test` du UI kit et confirmer réussite.
- [ ] Commit `feat(ui): dock workspace panels and add accessible responsive transitions`.

### Task 3: Préférences de disposition natives

**Files:** créer `apps/electrosim/lib/runtime/workspace_layout_preferences.dart` et `apps/electrosim/test/workspace_layout_preferences_test.dart` ; raccorder dans `main.dart`.

**Interfaces:**
- `WorkspaceLayoutPreferences(File file)` ; `static Future<WorkspaceLayoutPreferences> createDefault()` avec `getApplicationSupportDirectory()`, fichier `ElectroSim/workspace-layout-v1.json` ; `Future<Map<String,Object?>?> load()` ; `Future<void> save(Map<String,Object?> state)`.
- Sans nouvelle dépendance : utiliser `dart:io` comme la persistance native actuelle. Un constructeur recevant un File permet tests sans plugin. Ne pas annoncer un nouveau support web.
- Sauvegarde sérialisée vers un fichier temporaire puis renommage ; nettoyage temporaire ; charge absente/corrompue => null ; erreur d’écriture remontée à l’appelant qui affiche une information non bloquante.
- Le contrôleur est détenu par la page ; listener de préférence avec debounce 300 ms et dernière demande gagnante. Annuler timer et listener à dispose ; jamais de setState tardif.

- [ ] Écrire tests roundtrip, fichier absent, JSON invalide, écritures successives/concurrentes et chemin non inscriptible : `load()` retourne le dernier état valide et l’erreur d’écriture est capturable.
- [ ] Lancer `flutter test test/workspace_layout_preferences_test.dart` dans app : échec attendu API absente.
- [ ] Implémenter store et raccordement ; defaults utilisables avant chargement. Si l’utilisateur a déjà modifié la disposition, ne pas écraser son choix par une lecture tardive.
- [ ] Tester chargement tardif et fermeture de page avec écriture en cours ; erreurs traitées, fichier de circuit jamais modifié.
- [ ] Relancer tests ciblés puis `test/f17_persistence_test.dart` : succès, sans prétendre corriger les défauts préexistants de sauvegarde de circuit.
- [ ] Commit `feat(ui): persist workspace layout independently of circuit saves`.

### Task 4: Viewport stable et gestes électriques

**Files:** modifier viewport, son test existant, `main.dart` ; créer `apps/electrosim/test/professional_workspace_geometry_test.dart`.

**Interfaces:**
- Ajouter `void preserveWorldCenterOnResize(Size previousSize, Size nextSize)` au `ViewportController`. Si tailles finies/non vides et différentes : conserver `screenToWorld(previousSize.center(Offset.zero))` au nouveau centre, scale inchangée ; notifier une fois. Ignorer dimensions invalides.
- Dans la page, retenir la dernière taille ; callback `void _onWorkspaceCanvasSizeChanged(Size size)` ; annuler les gestes actifs avant resize spontané, adapter le viewport, sans toucher `_layout` ni `_circuit`.
- Raccorder `onBeforeLayoutChange` à l’annulation existante, et verrouiller les séparateurs pendant le geste. `_canvasDropKey` reste dans le canvas effectif ; les conversions global→local→world existantes doivent être vérifiées, pas remplacées par des offsets fixes.

- [ ] Ajouter test `resize preserves world center without changing scale` : tailles 1000×700 puis 700×700 ; avant/après centres monde identiques à 1e-6, scale identique ; dimensions invalides ignorées.
- [ ] Lancer `flutter test test/viewport_controller_test.dart` dans canvas : échec attendu API absente.
- [ ] Implémenter méthode puis intégration du callback ; ne pas recentrer automatiquement tout le circuit après chaque resize.
- [ ] Tester circuit fixture : ouvrir/fermer/redimensionner, positions du layout et routes inchangées ; quick-add et drop donnent les coordonnées attendues.
- [ ] Tester connexion par vrais gestes aux coordonnées des bornes après resize ; resize pendant aperçu de fil => geste annulé sans connexion fantôme. Tester un canvas vide et un changement de domaine.
- [ ] Lancer tests geometry puis `test/f9_canvas_interaction_test.dart`, `test/f18_g6_multiselect_test.dart`, `test/f18_g3r1_point06_topbar_actions_rotation_test.dart` dans app, et tests viewport dans canvas : succès.
- [ ] Commit `fix(ui): preserve circuit geometry and pointer mapping across dock changes`.

### Task 5: Barre, palette et inspecteur cohérents avec la maquette

**Files:** modifier theme, `main.dart`, palette et context panels ; créer `apps/electrosim/test/professional_workspace_controls_test.dart`.

**Interfaces:**
- Conserver signatures/callbacks métier de `_WorkspaceTopBar` et `_StatusBar`, clés des actions et restrictions actuelles. Hauteurs adaptées au texte ; commandes secondaires dans menu libellé si manque de place.
- Afficher Lancer/Pause avec libellé et état réel ; réinitialiser explicite ; domaine et actions de panneaux en zones 48×48 px. Sauvegarder/ouvrir utilisent leurs callbacks réels. Aucun label Enregistré sans confirmation du store de circuit.
- Palette : conserver catégories, recherche et quick-add ; renforcer séparation et contraste, infobulles complètes sur ellipses. Inspecteur : titres « Réglages » et « Mesures », détails de calcul accessibles ; formulaires verticaux si largeur/texte imposent cette adaptation.

- [ ] Écrire test `Mesures remains clickable below permanent toolbar` avec fixture réelle 1440×900 : `expect(find.text('Mesures').hitTestable(), findsOneWidget)` ; tap puis vérifier contenu de mesures. Ce test doit reproduire la régression connue avant correction.
- [ ] Écrire scénarios 390×844/1024×768, texte 1.5/2.0 : absence d’exception et actions clés atteignables au clic ; taille/labels des cibles passent, défilement vers champs bas possible.
- [ ] Tester Lancer/Pause, réinitialiser, rotation et suppression avec leurs effets métier ; mode élève lecture seule conserve interdictions ; navigation supervision/session inchangée.
- [ ] Lancer `flutter test test/professional_workspace_controls_test.dart` : conserver la preuve des échecs initiaux, puis implémenter styles et adaptativité.
- [ ] Lancer tests ciblés puis navigation, shell, instruments, propriétés et TP existants. Corriger les régressions, sans supprimer les assertions métier utiles.
- [ ] Commit `feat(ui): polish permanent controls and readable component panels`.

### Task 6: Qualification et livraison reviewable

**Files:** créer `docs/validation/professional-workspace-phase-a.md` et captures ; modifier uniquement les tests de contrats réellement remplacés par la disposition nouvelle.

- [ ] Lancer `dart format --output=none --set-exit-if-changed` sur fichiers modifiés ; `flutter analyze` dans app, canvas et UI kit ; `git diff --check` : aucune erreur nouvelle.
- [ ] Lancer suites app, canvas et UI kit complètes ; conserver les logs et distinguer défauts préexistants de régressions de branche. Tous les nouveaux tests doivent passer ; pas de test de chevauchement laissé intentionnellement rouge dans la livraison.
- [ ] Capturer accueil, atelier desktop, compact et texte agrandi. Vérifier visuellement polices, onglets, boutons et circuit ; annoncer précisément que ce sont des rendus de test si aucun appareil n’a été utilisé.
- [ ] Instrumenter/mesurer les quatre actions 400 composants sur appareil profile/release disponible : ouverture panneau, déplacement, zoom, clic de connexion. Rapporter p50/p95/frame budget avec hardware et topologie. Si plateforme indisponible, documenter limite et protocole reproductible ; ne pas transformer des widget tests en garantie 60 Hz.
- [ ] Relire le diff complet et le rapport par rapport à la spécification ; aucune fonction métier perdue, pas de bouton fictif, pas de publication involontaire de données.
- [ ] Préparer commit final et PR décrivant lot A, validation et lots B/C encore à réaliser. Utiliser la connexion GitHub disponible sans exposer de secrets ; ne pas fusionner sans instruction pour cette refonte.

## Self-review and handoff

Couverture : état/tokens tâche 1 ; disposition et réduction des animations tâche 2 ; préférences tâche 3 ; stabilité du monde et gestes tâche 4 ; commandes/formulaires/droits tâche 5 ; qualification tâche 6. Les cinq risques Review Focus ont chacun des tests explicitement attribués. Les API et valeurs sont cohérentes avec la spécification ; les anciens breakpoints de l’accueil sont conservés intentionnellement.

Recommandation : exécution native, les six tâches dépendant fortement des mêmes contrats de disposition et de viewport. Aucun sous-agent n’a été lancé. Revue de ce plan et choix du mode d’exécution attendus avant modification du code de production.
