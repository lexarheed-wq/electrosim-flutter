# M11 — Qualité visuelle des composants

Le rendu F18 utilise une seule source visuelle pour la palette et la platine.

## Règles

- les modèles courants disposent d'un symbole électrique spécifique ;
- les protections, commandes, récepteurs rotatifs, bobines et sources ne sont plus représentés par un rectangle générique identique ;
- les bornes restent visibles et cohérentes avec la géométrie de câblage ;
- le canvas de base ne peint plus les identifiants techniques `motor_dc`, `breaker_dc`, etc. derrière les symboles ;
- V1 reste une référence de lisibilité/identité visuelle, mais aucun renderer JavaScript n'est copié dans Flutter.
