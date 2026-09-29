# Rapport F7-R3 — Renforcement de couverture PV

## Défaut reproduit

La porte F7-R2 exécute correctement les 12 tests PV : **12/12 PASS**. Le blocage intervient ensuite sur la porte de couverture :

- lignes couvertes : 261 ;
- lignes totales : 298 ;
- couverture : **87,58 %** ;
- seuil F7 : **90 %**.

Le solveur n'est donc pas en échec fonctionnel ; la phase reste bloquée parce que plusieurs branches défensives et cas limites du solveur PV n'étaient pas exercés par les tests.

## Correction

Le seuil de 90 % n'est pas abaissé. La suite de tests PV est enrichie pour couvrir explicitement :

- les valeurs par défaut d'irradiance et de température lorsque les réglages sont absents ;
- le rejet d'une irradiance négative ;
- le rejet d'une température non finie ;
- le contrôle de la fenêtre DC lorsqu'un onduleur est dégradé ;
- le cas d'une tension PV calculée à 0 V sans courant ni sortie AC fictifs ;
- le cas limite `referenceIrradianceWm2 = 0`, sans division par zéro ;
- les deux états du getter `PvSolveResult.isSolved`.

Aucune équation du solveur, aucun contrat F1-F6 et aucun seuil de qualité n'est modifié.

## Critère

La porte reste inchangée : `F7-PV` doit atteindre **>= 90 %** puis l'ensemble F7 doit se terminer par `F7_GATE_PASS`.

## Statut

CANDIDAT. Validation réelle requise sur le toolchain Monterey verrouillé.
