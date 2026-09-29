# F5 — Solveur AC monophasé

## Objet
Introduire un solveur AC1 Dart pur fondé sur les phasors RMS complexes et une formulation MNA complexe.

## Entrées
- `CircuitState.mode == ac1`
- `TopologyGraph` correspondant exactement au circuit et à sa révision
- `settings.frequencyHz` fini et strictement positif

## Modèles initiaux
- `resistor` : `resistanceOhm > 0`
- `inductor` : `inductanceH > 0`, `Z = jωL`
- `capacitor` : `capacitanceF > 0`, `Z = 1/(jωC)`
- `impedance` : `R + jX`
- `ac_voltage_source` : `voltageRmsV`, `phaseDeg`
- `ac_current_source` : `currentRmsA`, `phaseDeg`

## Résultats
Le solveur publie tensions nodales et courants de branche complexes, puis dérive pour chaque branche `P`, `Q`, `S` et facteur de puissance à partir de `S = V × conj(I)`.

## Interdictions
- aucune dépendance Flutter/UI ;
- aucune valeur décorative ;
- aucune assimilation AC à du CC ;
- aucune grandeur P/Q/S/cosφ sans courant/tension réellement résolus.

## Porte F5
- cas résistif, inductif et capacitif verts ;
- unités/angles phasor testés ;
- analyse statique et garde d'architecture vertes ;
- couverture noyau F5 >= 90 % ;
- résidus numériques sous le seuil ;
- benchmark AC1 enregistré.
