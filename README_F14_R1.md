# ElectroSim Flutter — F14-R1

Phase F14: sauvegardes multiples, reprise, import/export et persistance versionnée.

## Contrats

- `SavedCircuitDocument` porte un `schemaVersion`, l'identité de sauvegarde, les dates UTC, `engineVersion` et le `CircuitState` complet.
- `LocalStorageRepository` liste explicitement les sauvegardes et n'ouvre jamais arbitrairement « la dernière ».
- Écriture atomique: fichier temporaire validé, sauvegarde `.bak`, remplacement, rollback en cas d'échec.
- Reprise au démarrage d'un `.bak` valide si le fichier cible manque; fichiers `.tmp` abandonnés supprimés.
- Import JSON versionné avec refus d'écrasement silencieux.
- Export CSV et PDF séparés de l'action Enregistrer.
- Migration explicite du schéma v0 vers v1 et rejet des versions inconnues.
- Les sauvegardes utilisateur restent indépendantes des bibliothèques système d'exemples et de pannes.

## Gate

`./validate.sh` doit terminer par `F14_GATE_PASS`.
