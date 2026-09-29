# F9-R8 — Stabilisation palette et glisser-déposer

## Défaut remonté

Le gate F9-R7 terminait avec plusieurs échecs widget. La dernière trace visible concernait `long-press drag from palette drops a component on the canvas`.

## Causes corrigées

1. **Collision d’identifiant** : le démonstrateur contient déjà `lamp-1`, alors que l’ancien compteur global pouvait recréer `lamp-1` lors d’un ajout de lampe. `CircuitState` rejetait correctement cet état avec `DomainErrorCode.duplicateId`.
2. **Test dépendant de la virtualisation** : après `Voir plus`, un élément situé loin dans le `ListView` n’est pas garanti d’être construit tant qu’il n’est pas dans la zone de cache/viewport. Le test vérifie désormais l’état expansé et le nombre de résultats, puis la recherche filtrée.
3. **Geste de drag trop fragile** : le test attend maintenant 300 ms (> délai 180 ms du `LongPressDraggable`), effectue un petit mouvement de prise puis rejoint la zone de dépôt.

## Implémentation

L’application utilise `_allocateElementId(keyName)` qui balaie les identifiants déjà présents dans les composants et sources et choisit le premier suffixe libre. Les coordonnées graphiques restent séparées dans `CircuitVisualLayout`.

## Non-régression ajoutée

Un test ajoute volontairement une nouvelle lampe alors que `lamp-1` existe déjà et exige `lamp-2`, sans exception.

## Gate attendu

`F9_R8_GATE_PASS`
