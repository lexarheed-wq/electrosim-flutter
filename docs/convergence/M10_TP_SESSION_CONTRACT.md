# M10 — TP, session et supervision

## M10A — autorité et cycle de vie

- Le professeur crée et publie le TP.
- Un élève connecté reste en état « prêt » tant que le professeur n'a pas déclenché le démarrage collectif.
- Le serveur LAN refuse une transition `published -> started` provenant d'un élève.
- Une remise rend immédiatement le montage élève non modifiable.
- La note automatique reste disponible au professeur, qui peut saisir une note finale bornée.
- Le professeur peut annuler un TP non remis ; l'activité devient fermée et non modifiable.
- Reconnexion : le snapshot professeur reste l'autorité de cycle de vie.

## Sécurité

- Les payloads élève ne contiennent pas `teacherTruth`, causes racines ou réparations attendues.
- Les bibliothèques de pannes finales seront reconstruites depuis zéro ; les fixtures V2 actuelles restent techniques.
