# ElectroSim Flutter — F11-R1 Candidate

Phase F11 : bibliothèque de pannes neuve, autonome et indépendante des exemples.

Critères principaux : réparabilité testée, zéro fuite `teacherTruth`, aucun `exampleId`, régressions F0→F10 vertes.

```bash
chmod +x validate.sh tools/*.sh
./validate.sh
```

Marqueur attendu : `F11_GATE_PASS`.
