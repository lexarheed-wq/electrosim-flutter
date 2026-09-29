# F14-R1 — Storage / import-export / recovery

Baseline: F13-R1 validée (`F13_GATE_PASS`).

Implémentation:
- package Dart pur `electrosim_storage`;
- sauvegardes locales multiples et ouverture explicite;
- format JSON versionné et migration v0 -> v1;
- écriture atomique temp/backup/rename et récupération après interruption;
- import/export JSON;
- exports CSV et PDF distincts;
- tests round-trip, corruption/version, multi-sauvegardes, overwrite, reprise et sécurité d'identifiant.

Le gate F14 conserve les régressions F9-F13 et ajoute les audits stockage F14.
