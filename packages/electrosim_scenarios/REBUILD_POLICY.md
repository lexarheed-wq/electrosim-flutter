# Politique de reconstruction des bibliothèques ElectroSim

Statut : **M0-CONVERGENCE-R1 — verrou architectural**.

## 1. Bibliothèque de schémas

- Reconstruction intégrale depuis zéro.
- Un schéma est un circuit sain, câblé, fonctionnel et validé par le solveur.
- Aucun schéma V1 n'est importé ou converti.
- Aucun titre, ID, structure de circuit, ordre de composants ou payload V1 n'est utilisé comme donnée d'entrée de génération.
- V1 peut servir uniquement d'oracle général pour vérifier des comportements du moteur, jamais comme catalogue à recopier.

## 2. Bibliothèque de pannes

- Reconstruction intégrale depuis zéro.
- Une panne est un scénario autonome qui contient directement son `faultyCircuitState`.
- Aucun scénario V1, FaultEngine injecté, titre, ID, circuit, teacher-truth ou réparation V1 n'est migré.
- Aucun scénario final ne dépend d'un exemple sain existant.
- La vérité professeur reste privée et séparée du payload élève.

## 3. Statut des catalogues F10/F11/F16 de la baseline G3R1

Ils sont conservés temporairement comme **fixtures techniques V2** afin de ne pas casser les tests de domaine pendant la convergence. Ils ne sont pas promus comme bibliothèque produit et ne constituent pas le point de départ éditorial des nouvelles bibliothèques.

## 4. Gate de conformité

Le gate M0 doit échouer si :

1. la matrice de migration autorise du contenu V1 pour Exemples ou Pannes ;
2. `electrosim_scenarios` importe un fichier depuis `reference/` ou une arborescence legacy ;
3. les fixtures baseline ne sont plus explicitement marquées non-production ;
4. un pont `exampleId -> fault` est réintroduit comme mécanisme d'architecture.
