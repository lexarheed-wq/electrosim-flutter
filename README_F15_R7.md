# ElectroSim Flutter — F15-R7

F15-R7 ajoute une qualification multi-plateforme reproductible sans fabriquer de preuve :

- workflow CI pour macOS, Windows, Linux, Android et iOS ;
- une preuve JSON par cible, produite uniquement après build + smoke test réels ;
- bundle `F15_EVIDENCE_BUNDLE.zip` téléchargeable depuis la CI ;
- import local strict via `tools/f15_import_evidence_bundle.sh` ;
- validation du target, du host, du SHA-256 d'artefact, du smoke test et du mode hors ligne avant import ;
- le gate global reste bloqué tant que les cinq preuves réelles ne sont pas présentes.

Aucun `skip`, aucune preuve synthétique et aucune rétrogradation des exigences F15.
