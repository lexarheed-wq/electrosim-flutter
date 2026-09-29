# F9 — Maquettes de référence pré-implémentation

**Statut : préparation seulement.** Ces maquettes ne sont ni du code Flutter ni des goldens de validation. Elles figent la composition visuelle avant ouverture de F9.

## Écrans fournis

1. `mockups/01_home_expanded.svg` — accueil professeur, trois entrées principales.
2. `mockups/02_workspace_expanded.svg` — workspace câblage desktop, Canvas dominant.
3. `mockups/03_student_troubleshooting_compact.svg` — élève mobile en Recherche de dérangement avec diagnostic contextuel.
4. `mockups/04_component_visual_system.svg` — langage graphique palette ↔ platine.

Chaque SVG possède un PNG de prévisualisation homonyme.

## Règles de lecture

- les maquettes ne prescrivent aucune logique électrique ;
- `CircuitState` et `SimulationResult` restent les seules sources électriques ;
- la structure responsive change, pas le sens métier ;
- les couleurs de statut UI ne remplacent jamais les codes électriques ;
- la fiche diagnostic n'est visible que pour l'élève en Recherche de dérangement ;
- les 217 éléments legacy restent une taxonomie visuelle, jamais une importation automatique.

## Décisions visuelles

- chrome sombre et neutre pour laisser le Canvas clair dominer ;
- accent cyan pour sélection/navigation active ;
- accent ambre réservé aux terminaux/cibles de câblage, sauf code électrique spécifique ;
- vert pour confirmation/santé de processus, rouge/rose pour erreur ou incompatibilité ;
- cartes et panneaux à rayon modéré ;
- densité réduite sur mobile, panneaux transformés en sheets.

## Non-contractuel

Les valeurs exactes de couleurs, rayons et espacements seront converties en tokens F9.1 uniquement après `F8_GATE_PASS` et revue visuelle du Canvas F8.
