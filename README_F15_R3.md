# ElectroSim Flutter — F15-R3

Correctif de qualification multi-plateforme.

- `f15_prepare_runner.sh` réserve stdout à un protocole machine lisible `F15_RUNNER_PATH=...`.
- Les logs de `flutter pub get` sont envoyés sur stderr.
- `f15_qualify_target.sh` valide le protocole et l’existence du runner avant `cd`.
- Élimine le défaut `File name too long` provoqué par la capture des logs Flutter dans la variable du chemin temporaire.
