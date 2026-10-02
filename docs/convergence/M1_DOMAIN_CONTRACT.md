# M1 — Contrat de domaine de convergence

Statut : **M1A-DOMAIN-CONTRACT-R1**

## Décision

Le modèle V2 reste autoritaire : `CircuitState`, `ComponentInstance`, `SourceInstance`, `Terminal` et `Connection` ne sont pas remplacés par les objets V1. Les apports V1 sont traduits uniquement sous forme de sémantiques physiques explicites et testables.

## Premier contrat récupéré de V1

V1 avait corrigé une ambiguïté importante : **le courant nominal d'un récepteur n'est pas le calibre de sa protection**. V2 ne doit jamais réunir ces deux grandeurs sous une même clé générique.

Le domaine Flutter introduit donc :

- `ReceiverNominalRating`, avec `receiverNominalVoltageV`, `receiverNominalCurrentA`, `receiverNominalPowerW` ;
- `ProtectionRating`, avec `protectionRatedCurrentA`.

Ces contrats sont des valeurs de domaine. Ils n'ajoutent encore aucune logique de déclenchement, de temporisation ou de surcharge au solveur : ces comportements appartiennent à M6 et seront fondés sur les résultats du solveur.

## Règles

1. aucune clé V1 `ratedCurrent` ou `Imax` n'est acceptée comme alias automatique ;
2. aucune donnée de bibliothèque V1 n'est transformée ;
3. les nouvelles valeurs utilisent des unités explicites dans leur nom (`V`, `A`, `W`) ;
4. toute valeur déclarée doit être numérique, finie et strictement positive ;
5. l'absence de données nominales reste autorisée ;
6. le schéma JSON `CircuitState` reste en version 1 : les ratings résident dans `parameters` et n'imposent aucune migration de document.

## Pourquoi ce choix est non invasif

Les solveurs actuels continuent à lire `modelType`, `parameters`, `condition` et `controlState` comme avant. Le contrat M1A ne modifie pas leur comportement. Il fournit une sémantique normalisée que M6 pourra utiliser pour implémenter surcharge, protection et coordination sans reproduire les confusions historiques.
