# ElectroSim F16-R1 — Reconstruction progressive du catalogue

F16-R1 ajoute un premier lot contrôlé au catalogue neuf, sans import de contenu legacy.

## Contenu qualifié

- 5 exemples CC sains au total, dont 2 nouveaux en F16-R1.
- 3 scénarios de panne autonomes au total, dont 1 nouveau en F16-R1.
- Tous les items sont validés et portent une signature déterministe.
- Aucun `exampleId` dans les scénarios de panne.
- Aucune donnée `teacherTruth` dans le payload élève.
- Aucune importation de catalogue historique.

## Gate

Le workflow `F16 catalog qualification` exécute :

- analyse statique du package ;
- régressions F10/F11 ;
- tests F16 du catalogue ;
- audit `docs/f16/audit_catalog.json`.

Le marqueur de réussite est :

```
F16_GATE_PASS
```
