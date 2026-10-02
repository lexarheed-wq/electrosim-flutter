# M1 — Analyse des écarts de domaine V1 / V2

## À conserver tel quel depuis V2

- `CircuitState` immuable et versionné ;
- IDs typés ;
- terminaux et connexions explicites ;
- `ElectricalMode` DC / AC1 / AC3 / PV ;
- `ComponentCondition` normal / openCircuit / shortCircuit / degraded / disabled ;
- paramètres et états de commande sérialisables sans dépendance UI.

## Capacités V1 à réexprimer, pas à copier

- distinction charge nominale / calibre protection ;
- protections ouvertes/déclenchées et états thermiques ;
- contacteurs et relais multi-branches avec bobine + contacts ;
- récepteurs avec états OFF / UNDERLOAD / NORMAL / OVERLOAD / SEVERE_OVERLOAD ;
- limitations de sources ;
- appareils multi-pôles et états contrôlés.

## Placement prévu

- données nominales : `electrosim_domain` (M1) ;
- branches/terminaux physiques : `electrosim_topology` (M2) ;
- équations électriques : solveurs DC/AC (M3–M5) ;
- protections, contacteurs, états et temporisations : M6 ;
- mesures : M7 ;
- diagnostics/EIE : M9.

Cette séparation empêche le domaine de devenir un second solveur et empêche l'UI de porter la physique.
