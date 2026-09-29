# Rapport F7-R1 — Candidat PV et énergie

## Objectif

Introduire un module PV déterministe et un `EnergyEngine` sans modifier les contrats validés F1–F6.

## Ajouts

- package `electrosim_pv` ;
- `SolverPV`, diagnostics structurés, résultat PV et état physique de l'onduleur ;
- source PV au MPP avec irradiance/température réellement prises en compte ;
- onduleur avec limites DC, puissance nominale, rendement et dérating explicite ;
- charges résistives AC explicites et limitation physique de la tension en déficit de puissance ;
- package `electrosim_energy` ;
- W, Wh, kWh, pertes, rendement et historique borné ;
- adaptateur `EnergyPowerSample.fromPvResult` ;
- benchmarks PV et énergie ;
- gardes d'architecture et porte cumulative F7.

## Cas de non-régression prioritaires

- `PV-001` : onduleur défectueux => tension, courant et puissance de sortie nuls ;
- fonctionnement nominal avec bilan puissance entrée = sortie + pertes ;
- irradiance réduite => puissance réellement réduite ;
- température => coefficients appliqués explicitement ;
- tension DC hors plage => sortie nulle ;
- dérating => puissance nominale réduite uniquement par paramètre explicite ;
- `ENERGY-001` : intégration W -> Wh/kWh sur temps simulé ;
- rejet d'un bilan puissance incohérent au lieu d'une correction silencieuse.

## Statut

CANDIDAT. Le jalon devient F7 validé uniquement après `F7_GATE_PASS` sur le SDK Flutter/Dart verrouillé Monterey.
