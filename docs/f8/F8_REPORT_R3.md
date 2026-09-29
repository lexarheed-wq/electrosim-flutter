# Rapport F8-R3 — Validation autonome de la référence legacy

## Déclencheur

L'exécution physique de F8-R2 sur le Mac Monterey a franchi les contrôles Flutter initiaux puis s'est arrêtée à `legacy-reference`. Le vérificateur signalait l'absence de `audit/legacy_reference_analysis.json`.

## Cause racine

Le dossier `audit/` est volontairement exclu du ZIP candidat car il contient des sorties d'exécution. Cependant, `verify_legacy_reference.py` utilisait l'analyse legacy stockée dans ce dossier comme prérequis. Un dossier de travail auteur passait donc le contrôle, tandis qu'une extraction propre du ZIP échouait.

## Correction minimale

- `run_f8_gate.sh` exécute désormais `analyze_legacy_reference.py` avant `verify_legacy_reference.py` ;
- l'analyse est reconstruite depuis le ZIP historique sanctuarisé et le baseline F0 ;
- le garde statique F8 vérifie la présence et l'ordre de ces deux étapes ;
- aucun code Canvas, solveur, modèle électrique ou interaction utilisateur n'a été modifié.

## Non-régression

Le scénario à couvrir est une extraction propre ne contenant aucun dossier `audit/`. La porte F8 doit pouvoir créer l'analyse nécessaire et poursuivre sans artefact auteur préexistant.

## Statut

F8 reste **CANDIDAT** jusqu'à obtention de `F8_GATE_PASS` sur le Mac Monterey de validation.
