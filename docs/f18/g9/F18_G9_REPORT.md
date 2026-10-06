# F18 — G9 EIE / IA interne

## Portée

G9 recentre EIE sur le diagnostic interne du moteur ElectroSim. Il ne s'agit pas d'un
coach élève et aucune cause n'est inventée par l'interface.

## Invariants

- toute alerte EIE cite au moins un `evidenceId`;
- les preuves proviennent de TopologyEngine, des solveurs CC/AC1/AC3/PV ou des états
  de charge calculés;
- un fonctionnement normal reste silencieux : aucun conseil sans preuve;
- le runtime PV utilise le même `DiagnosticEngine` que les autres domaines;
- les diagnostics PV reprennent les codes et messages réellement émis par `SolverPV`;
- l'onglet EIE est réservé au professeur;
- la fiche Diagnostic élève reste distincte et aucun coach EIE élève n'est réintroduit;
- les détails techniques sont repliés par défaut et accessibles volontairement par le
  professeur;
- G9 n'altère aucun solveur et n'applique aucune correction automatique au circuit.

## Qualification

Le workflow G9 exécute avec Flutter 3.38.10 / Dart 3.10.9 :

1. contrat statique `tools/f18_g9_contract.py`;
2. format Dart strict des sources G9;
3. `flutter analyze`;
4. tests runtime/UI G9;
5. `dart analyze` et `dart test` du package `electrosim_diagnostics`;
6. régression EIE F17;
7. non-régression G8 TP professeur/élève;
8. non-régression G7 instruments/propriétés.

## Critère de fermeture

G9 est PASS uniquement après une qualification entièrement verte sur le SHA exact de
la branche G9, puis une nouvelle qualification verte sur le SHA de fusion de la branche
d'intégration.
