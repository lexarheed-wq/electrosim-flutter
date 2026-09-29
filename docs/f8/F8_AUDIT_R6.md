# Audit F8-R6 — Durcissement de la validation et du lancement visuel

## Contexte

F0 à F7 ont déjà franchi leurs portes physiques sur le Mac Monterey de référence. F8-R5 reste le candidat fonctionnel du Canvas : la correction R5 stabilise le clic simple, le pan et le double-clic sans recognizer `onDoubleTap` concurrent. L'utilisateur n'ayant temporairement pas accès au Mac, R6 ne modifie pas le code Dart de production du Canvas : il durcit uniquement la preuve de validation et le lancement visuel.

## Audit du Canvas existant

Points conformes conservés :

- `CircuitState` reste fourni en entrée et n'est jamais muté par le Canvas ;
- les positions/routages graphiques restent dans `CircuitVisualLayout` ;
- `HitTestEngine` est centralisé ;
- sélection, appui long, câblage borne-à-borne, pan et zoom sont traduits en callbacks/état graphique ;
- aucun import de solveur, topologie, mesure, énergie ou PV n'existe dans `electrosim_canvas` ;
- le rendu et les interactions disposent de tests widget, de goldens sur trois tailles et d'un benchmark p95.

Risques constatés dans le protocole R5 :

1. **Golden bootstrap auto-validant** : lorsque les PNG de référence étaient absents, la même porte les créait puis les comparait immédiatement. Cela prouvait la reproductibilité du rendu, mais pas l'approbation de la première référence visuelle.
2. **Lancement macOS manuel et mutatif** : la procédure `flutter create --platforms=macos .` devait être lancée à la main dans le candidat et ajoutait des fichiers de plateforme dans le dossier source.
3. **Cycle de débogage coûteux** : pour une correction purement F8, le seul script disponible rejouait toute la porte cumulative F1→F8.

## Corrections R6

### 1. Baseline golden approuvée explicitement

La porte F8 distingue désormais deux états :

- `F8_GATE_GOLDEN_REVIEW_REQUIRED` : tous les contrôles automatiques ont passé, mais la première baseline visuelle n'a pas encore été approuvée humainement ;
- `F8_GATE_PASS` : les trois goldens ont été approuvés puis leurs SHA-256 sont verrouillés dans `docs/f8/F8_GOLDEN_BASELINE.json`.

`tools/approve_f8_goldens.py --approve` exige une action explicite et enregistre taille + SHA-256 de chaque PNG. `verify_f8_golden_baseline.py` bloque toute modification silencieuse ultérieure.

### 2. Lancement visuel non destructif

`./run_visual.sh` :

- exige une preuve de porte automatique `PASS` ou `GOLDEN_REVIEW_REQUIRED` ;
- recherche le Flutter 3.38.10 verrouillé ;
- crée un runner macOS dans un dossier temporaire ;
- copie uniquement l'application, `electrosim_domain` et `electrosim_canvas` ;
- génère les fichiers macOS dans cette copie ;
- lance `flutter run -d macos` ;
- ne modifie jamais le candidat source.

### 3. Boucle rapide non officielle

`./validate_f8_quick.sh` permet de rejouer analyse, gestes, goldens existants et benchmark F8 sans prétendre valider la phase. Le script affiche explicitement `F8_QUICK_CHECK_PASS (not an official phase gate)`.

## Vérifications exécutées dans l'environnement de préparation

- parse Bash des scripts critiques : PASS ;
- `f8_static_contract_check.py` : PASS ;
- tests tooling R6 : 6/6 PASS ;
- script d'approbation sans `--approve` : refus attendu ;
- vérificateur de baseline sans approbation : échec attendu ;
- aucun fichier Dart de production F8 modifié par R6.

## Risques résiduels

- F8-R5/R6 doit toujours être exécuté physiquement avec Flutter 3.38.10 sur le Mac Monterey de référence ;
- les trois goldens doivent être générés puis inspectés avant approbation initiale ;
- la fluidité perçue et l'ergonomie réelle du Canvas ne peuvent pas être validées sans ouverture graphique ;
- F9 ne doit pas être ouvert officiellement avant `F8_GATE_PASS` et contrôle visuel.

## Décision

**F8-R6 = CANDIDAT renforcé, NO-GO vers F9 tant que la porte physique et la revue visuelle ne sont pas terminées.**
