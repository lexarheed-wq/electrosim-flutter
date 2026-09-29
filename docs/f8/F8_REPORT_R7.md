# Rapport F8-R7 — Audit approfondi et corrections d'interaction

## Statut

**CANDIDAT / NO-GO vers F9** tant que `F8_GATE_PASS` et la revue visuelle sur Mac Monterey ne sont pas obtenus.

## Modifications de production F8

- hit-testing stable en pixels écran via `viewportScale` ;
- clic fond = annulation du câblage en cours ;
- nettoyage de la prévisualisation après annulation/connexion ;
- fil sélectionné rendu visuellement comme sélectionné ;
- collision de chaîne d'ID entre source/composant/connexion détectée explicitement.

Aucun calcul électrique n'a été ajouté au Canvas.

## Tests ajoutés

- tolérance de borne stable au zoom ;
- annulation `borne → fond → borne` sans connexion fantôme ;
- sélection d'un fil ;
- collision source/composant ;
- collision élément/connexion.

## Audit et préparation

- `tools/f8_deep_static_audit.py` ;
- `docs/f8/F8_DEEP_AUDIT_R7.md` ;
- `docs/f8/F8_PHYSICAL_VALIDATION_CHECKLIST.md` ;
- dossier `docs/f9/` de préparation uniquement, sans package F9 ni code UI kit.

## Contrôles exécutables sans Flutter dans l'environnement de préparation

- garde architecture F8 ;
- contrat statique F8 ;
- audit statique approfondi R7 ;
- tests Python de tooling R6/R7 ;
- parsing Bash ;
- génération/vérification du manifest F8.

## Contrôles restant obligatoires sur le Mac

- `flutter analyze` ;
- tests widget R7 ;
- goldens + revue ;
- benchmark p95 ;
- app analyze/test ;
- ouverture avec `run_visual.sh` ;
- checklist physique ;
- `F8_GATE_PASS`.
