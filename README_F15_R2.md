# F15-R2 — Qualification plateforme avec toolchain verrouillée

Correctif de F15-R1 : tous les scripts de préparation et qualification de plateformes résolvent désormais explicitement la toolchain Flutter/Dart verrouillée du projet. Aucun script F15 critique ne dépend d'une commande `flutter` globale dans le PATH.

## Non-régression
- résolution Flutter 3.38.10 / Dart 3.10.9 depuis `.toolchain` ou un candidat voisin validé ;
- bootstrap local offline si nécessaire ;
- test statique `F15_TOOLCHAIN_CONTRACT_PASS` ;
- correction du garde Windows avec `${OS:-}` sous `set -u`.
