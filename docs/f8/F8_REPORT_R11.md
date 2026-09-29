# F8-R11 — correction du packaging de la référence legacy

Date : 27 septembre 2026  
Statut : **CANDIDATE — validation macOS requise**

## Symptôme observé

Sur une extraction neuve de F8-R10, `./validate.sh` atteignait `f0-guard` puis levait `FileNotFoundError` sur :

`reference/legacy/ElectroSim-FIELDFIX01-R1.zip`

Le problème n'était pas le Canvas F8 : le paquet de distribution avait exclu l'oracle legacy alors que la garde F0 et l'analyse de référence en dépendent encore.

## Correction R11

1. Réintégration de l'archive legacy immuable sous son nom canonique.
2. Vérification de son SHA-256 attendu : `569e05908592e6dd615bd80b342f6c7a28249850951d353dac988c5d2e1187bd`.
3. Suppression d’un fixture temporaire de test `apps/electrosim/lib/guard_regression_legacy.js` qui ne doit jamais faire partie d’un candidat distribué.
4. `f0_guard.py` traite désormais l'absence éventuelle de l'archive comme une erreur de porte structurée au lieu d'un traceback.
5. `analyze_legacy_reference.py` crée désormais son dossier `audit/` si nécessaire, pour rester autonome hors du wrapper de porte.
6. Aucun fichier Dart de production F8 n'est modifié ; le gel de production R10 doit rester vert.

## Portée

Cette correction concerne uniquement l'autonomie du paquet et la robustesse de la validation. Elle n'ouvre pas F9 et ne modifie ni le noyau électrique ni le Canvas de production.
