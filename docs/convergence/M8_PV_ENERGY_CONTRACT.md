# M8 — PV et énergie

Audit de convergence : le noyau V2 PV/énergie est conservé.

## Capacités conservées et qualifiées

- irradiance et température explicites ;
- limites DC de l'onduleur ;
- limitation réelle de puissance et chute de tension de sortie ;
- panne onduleur => sortie AC, puissance et énergie aval nulles ;
- bilan puissance entrée/sortie/pertes ;
- accumulation d'énergie uniquement à partir du temps de simulation explicite.

## Ajout de convergence

Le réglage `shadingPct` est borné à 0–100 %. L'irradiance effective devient :

`irradianceEffective = irradianceWm2 × (1 - shadingPct / 100)`.

Aucun temps mur/rafraîchissement UI n'entre dans l'énergie.
