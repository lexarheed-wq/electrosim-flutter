# ElectroSim Flutter — F15-R1 candidate

Baseline : F14-R1 validée (`F14_GATE_PASS`).

F15 ajoute la qualification et le packaging multi-plateforme. Le noyau électrique et les phases antérieures restent gelés.

Voir `README_F15_R1.md`.

## F15-R2
La qualification multi-plateforme utilise désormais explicitement la toolchain Flutter/Dart verrouillée via `tools/f15_flutter_env.sh`, y compris lorsque `f15_qualify_current_host.sh` est lancé directement.

## F15-R5
Qualification hôte robuste : disponibilité plateforme vérifiée avant build ; aucune preuve PASS inventée pour une cible indisponible.

## F15-R7 — qualification multi-plateforme
La qualification F15 peut être exécutée sur les hôtes natifs ou via `.github/workflows/f15-platform-qualification.yml`. Les preuves produites peuvent être regroupées dans `F15_EVIDENCE_BUNDLE.zip`, puis importées localement avec `tools/f15_import_evidence_bundle.sh` avant `./validate.sh`.
