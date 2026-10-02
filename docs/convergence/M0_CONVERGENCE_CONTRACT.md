# ElectroSim — M0 Convergence Contract

Version : **M0-CONVERGENCE-R1**  
Base Flutter : F18-G3R1 recovery source (`f52da0acba9e93032433849756abfdea17dc442d`)  
Référence V1 : `ElectroSim-FIELDFIX01-R1.zip` — SHA-256 `569e05908592e6dd615bd80b342f6c7a28249850951d353dac988c5d2e1187bd`.

## Objectif

Converger les points forts fonctionnels et visuels de V1 vers l'architecture Flutter V2 **sans migrer l'architecture JavaScript historique ni les bibliothèques de schémas/pannes V1**.

## Invariants

1. V2/Flutter reste la base architecturale.
2. `CircuitState -> TopologyEngine -> Solver -> Results` reste le flux autoritaire.
3. Le Canvas et l'UI ne calculent jamais l'électricité.
4. Les comportements V1 utiles sont réexprimés en Dart et prouvés par tests ; le code V1 n'est pas copié comme architecture.
5. Les bibliothèques Schémas et Pannes sont reconstruites depuis zéro.
6. Aucun schéma/panne V1 n'est importé, converti ou utilisé comme seed.
7. Les pannes restent autonomes et ne dépendent pas d'un schéma sain.
8. Chaque portage doit être couvert par un test avant remplacement de son oracle V1.
9. Une fonctionnalité V1 ne peut être déclarée récupérée que si l'équivalent V2 est démontré.

## Ce que V1 peut fournir

- règles physiques et comportements observables à comparer ;
- cas limites et régressions connues ;
- objectifs de réalisme visuel des composants ;
- ergonomie et flux métier à reproduire lorsque pertinents ;
- idées de tests et d'audits.

## Ce que V1 ne fournit pas

- architecture runtime ;
- globals, monkey-patches, ordre de scripts ou adaptateurs legacy ;
- données de bibliothèques de schémas ;
- données de bibliothèques de pannes ;
- IDs/titres/payloads/circuits de catalogue ;
- mécanisme FaultEngine par injection.

## Ordre de convergence

M0 baseline/inventaire -> M1 domaine -> M2 topologie -> M3 CC -> M4 AC1 -> M5 AC3 -> M6 protections/appareillages -> M7 mesures -> M8 PV/énergie -> M9 EIE -> M10 TP/supervision -> M11 visuels composants -> M12 UI Figma/MagicPath -> M13 qualification.

Les bibliothèques produit Schémas/Pannes ont leur propre reconstruction après stabilisation des contrats moteur nécessaires ; elles ne sont jamais une sous-tâche de migration V1.
