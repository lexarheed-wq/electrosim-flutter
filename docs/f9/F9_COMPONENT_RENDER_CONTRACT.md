# F9 — Contrat de rendu composant

## 1. Identité unique

Un type de composant possède une silhouette canonique commune à la palette et à la platine. La palette peut simplifier le niveau de détail, jamais changer de métaphore.

## 2. Couches

1. silhouette mécanique/boîtier ;
2. marquage métier ;
3. bornes ;
4. états électriques issus de `SimulationResult` ;
5. états UI issus du contrôleur d'interface.

Les couches 4 et 5 restent distinctes.

## 3. États UI

`normal`, `hover`, `selected`, `focused`, `dragging`, `wireSource`, `wireCompatibleTarget`, `wireIncompatibleTarget`.

Aucun de ces états n'autorise à inférer `energized`, `running`, `faulted` ou une mesure.

## 4. Bornes

- position stable dans les coordonnées monde ;
- hit target ajusté en coordonnées écran ;
- étiquette de phase/polarité lisible à zoom pertinent ;
- indication d'incompatibilité explicite et accessible, pas couleur seule.

## 5. Familles visuelles

Sources, protection, commande, charges, machines tournantes, connexion, mesure, conversion, PV/énergie. Les familles partagent grammaire et métriques mais conservent leur forme physique reconnaissable.

## 6. Appareils animés

Une animation ne démarre que si `DeviceStateEngine` / `SimulationResult` fournit l'état fonctionnel correspondant. L'animation n'est jamais la source de cet état.
