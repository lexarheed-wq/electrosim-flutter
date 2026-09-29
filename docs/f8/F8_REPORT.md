# Rapport F8-R1 — Canvas Flutter interactif

## Portée

Première implémentation du moteur graphique Flutter. Cette phase ne contient aucune logique électrique nouvelle.

## Éléments ajoutés

- package `electrosim_canvas` ;
- `CircuitVisualLayout` indépendant du domaine électrique ;
- `ViewportController` monde/écran ;
- `HitTestEngine` centralisé ;
- `CircuitScenePainter` pour grille, fils, composants, sources et bornes ;
- `SimulatorCanvas` avec sélection, appui long/déplacement, câblage par bornes, pan, zoom et action contextuelle ;
- écran de démonstration F8 dans l'application Flutter ;
- tests widget des gestes ;
- trois golden tests ;
- benchmark de scène nominale avec budget 60 fps ;
- `audit_ui.json` généré par la porte ;
- garde d'architecture empêchant le Canvas d'importer les solveurs ou moteurs physiques.

## Décisions

Le déplacement d'un élément modifie uniquement `CircuitVisualLayout`. Le câblage ne modifie pas directement `CircuitState` : le Canvas émet une demande de connexion au niveau supérieur. Cela évite qu'un widget Flutter devienne une seconde source de vérité électrique.

## État

CANDIDAT. La validation réelle nécessite `./validate.sh` sur le toolchain Monterey verrouillé. La porte doit terminer par `F8_GATE_PASS`.
