# M2 — Topologie multi-branches canonique

Statut : **M2-TOPOLOGY-BRANCH-R1**

## Problème traité

La baseline V2 compile correctement les nœuds issus des conducteurs, mais n'expose pas encore la structure interne d'un composant multipolaire. Les solveurs seraient donc contraints de redéduire eux-mêmes qu'un disjoncteur 3P possède trois pôles indépendants ou qu'un contacteur possède trois pôles de puissance et une bobine.

## Solution

`TopologyGraph` expose désormais des `TopologyBranch` structurelles issues de `ComponentModelContract`.

Une branche contient :

- l'identifiant du composant ;
- l'identifiant canonique de branche ;
- le rôle (`powerPole`, `controlCoil`, etc.) ;
- les deux terminaux de l'instance ;
- les deux nœuds externes correspondants ;
- éventuellement l'indice du pôle.

## Invariant critique

**Une branche de composant ne fusionne jamais les nœuds conducteurs.** Un contact fermé, une résistance ou une bobine sont des éléments électriques entre deux nœuds ; ils ne sont pas des fils. Leur état et leurs équations appartiennent aux solveurs/M6.

## Robustesse

Si une instance annonce un `modelType` canonique mais possède un nombre de terminaux incompatible avec son contrat, la compilation topologique produit `componentContractMismatch` en erreur au lieu d'accéder à un index invalide.

## Compatibilité

- les modèles inconnus restent tolérés et ne produisent aucune branche structurée ;
- le constructeur historique `const TopologyEngine()` reste valide ;
- le registre est injectable pour les futurs modèles ;
- `TopologyGraph` accepte toujours les appels existants car `componentBranches` est optionnel ;
- aucun solveur n'est modifié à ce stade.
