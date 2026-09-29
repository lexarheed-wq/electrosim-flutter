# ElectroSim F10-R3

F10-R3 corrige la chaîne de régression visuelle F9 sans modifier les goldens ni les tests.

- Les 10 références F9 doivent provenir d'une baseline explicitement APPROVED.
- Chaque PNG est vérifié par SHA-256 contre `docs/f9/F9_GOLDEN_APPROVAL.json` avant copie.
- `ElectroSim-Flutter-F9-FINAL-VENTURA-FIX10-CANDIDATE` est prioritaire.
- Une baseline incohérente est refusée; aucun `--update-goldens`, aucun `skip`, aucune approbation automatique.
- `ELECTROSIM_F9_BASELINE=/chemin/...` permet de fournir explicitement la baseline validée.
