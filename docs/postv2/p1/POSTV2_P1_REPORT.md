# Post-V2 — P1 Robustification du moteur électrique et des règles de câblage

## Objet

P1 est la première évolution post-V2. Il durcit la frontière entre interface,
topologie, solveurs, états physiques et EIE avant tout ajout d'implantation
d'armoire ou de bibliothèque produit.

## P1.1 — Séparation des responsabilités

- Le Canvas conserve uniquement géométrie, placement, sélection, bornes,
  connexions et rendu.
- Aucune dépendance des packages solveur ou diagnostics n'est autorisée depuis
  `electrosim_canvas`.
- `TopologyEngine` reste l'autorité de structure électrique.
- `SolverDC`, `SolverAC1`, `SolverAC3` et `SolverPV` restent les autorités
  de résolution physique.
- `DeviceStateEngine` et le runtime interprètent les résultats.
- L'EIE observe les preuves du moteur ; il ne réécrit pas le circuit.

## P1.2 — Polarité et règles de connexion

La politique UI ne refuse que les invalidités structurelles :
auto-connexion, borne inconnue et doublon exact. Les tags `dcPositive`,
`dcNegative`, L1/L2/L3/N/PE restent des métadonnées. Une connexion + vers -
entre deux sources CC est donc représentable et ses conséquences sont laissées
au moteur.

## P1.3 — Associations de sources CC

Cas contractuels couverts :

- 12 V + 12 V en série = 24 V ;
- 24 V + 12 V en série = 36 V ;
- trois sources de 12 V en série = 36 V ;
- sources opposées 24 V et 12 V = tension algébrique 12 V ;
- point milieu utilisable ;
- sources idéales compatibles en parallèle : contrainte redondante reconnue ;
- sources idéales incompatibles en parallèle : diagnostic explicite
  `contradictoryIdealSource`.

### Correction moteur

Le solveur CC normalise désormais les contraintes idéales avant la MNA.
Une contrainte équivalente est marquée redondante sans rendre le système
singulier. Une contrainte incompatible est signalée explicitement avant la
résolution au lieu de retomber sur une matrice singulière générique.

## P1.4 — Comportement selon le type de récepteur

Couverture dédiée :

- résistance inversée : même grandeur électrique, signe de branche inversé ;
- lampe inversée : même comportement résistif ;
- diode/LED : conduction directe et blocage inverse ;
- moteur CC : inversion du signe de courant ; le sens d'animation est dérivé
  du courant signé du runtime ;
- bobine relais CC simple : comportement réversible ;
- bobine polarisée : assemblage canonique bobine + diode de roue libre, dont le
  comportement change réellement avec la polarité ;
- onduleur PV, régulateur PV et batterie PV : les inversions de raccordement
  sont diagnostiquées explicitement par `SolverPV`.

Aucun nouveau composant de bibliothèque n'est créé dans P1.

## P1.5 — Invariants physiques

Les tests P1 exigent simultanément :

- résidus numériques finis ;
- KCL sous tolérance ;
- KVL sous tolérance ;
- bilan de puissance fermé ;
- aucune valeur NaN ou infinie silencieuse ;
- reproductibilité du même `CircuitState` ;
- EIE capable de remonter un conflit de sources sans modifier le
  `CircuitState`.

## P1.6 — Non-régression

Le gate P1 exécute :

- contrat architectural P1 ;
- tests de câblage UI ;
- tests de sources CC ;
- tests de polarité des récepteurs ;
- tests de polarité PV ;
- invariants physiques ;
- preuve d'autorité passive de l'EIE ;
- direction d'animation moteur ;
- topologie et Canvas ;
- régression complète des packages domain, topology, solver DC, solver AC,
  controls, protection, measurements, PV, energy et diagnostics ;
- `flutter analyze` et la suite complète de l'application ElectroSim.

## P1.7 — Fermeture

P1 ne peut être déclaré fermé qu'après :

1. gate automatisé P1 entièrement vert sur un SHA unique ;
2. fusion dans la branche d'intégration ;
3. requalification de ce SHA intégré ;
4. build macOS Intel ;
5. validation physique P1 sur le Mac cible.

Marqueur automatisé attendu :

`POSTV2_P1_AUTOMATED_PASS`

Marqueur physique final attendu :

`POSTV2_P1_PHYSICAL_MAC_PASS`
