# F18 — G12 Qualification finale et candidat Mac Intel

## Objectif

G12R2 qualifie le candidat F18 après connexion réelle des bibliothèques produit G10B,
sans modifier le code produit validé par G10B et G11.
La base produit de référence est :

`236f2e011d286d819c22960a27b076c9b6b7e5cb`

Toute modification après cette base est limitée au contrat, au rapport et au workflow G12.

## Qualification automatisée

Le workflow G12 doit produire sur un SHA unique :

- contrat G12 et audit transversal G11;
- Flutter 3.38.10 / Dart 3.10.9;
- `flutter analyze` de l'application;
- suite Flutter complète de l'application;
- tests explicites LAN professeur/élève et TP;
- test end-to-end G10B des bibliothèques schémas/pannes;
- tests canvas critiques et bibliothèque V2;
- build macOS **release** sur runner Intel;
- preuve binaire `x86_64`;
- archive du candidat Mac;
- archive source du même SHA;
- SHA-256 des archives;
- fichier `BASE_COMMIT.txt`;
- checklist de validation physique.

## Validation physique obligatoire

L'automatisation ne peut pas déclarer `F18_PHYSICAL_MAC_PASS`.

Le candidat doit être vérifié sur le Mac Intel cible, avec au minimum :

1. lancement de l'application sans crash;
2. Accueil → Session → centres Maintenance/Conception;
3. création/entrée dans une session et retour tableau de bord;
4. drag, pan, zoom/trackpad et clipping du canvas;
5. câblage CC, y compris deux alimentations CC en série;
6. bornier CC séparé du bornier triphasé;
7. sélection multiple uniquement avec Ctrl/Cmd/Shift, désélection et suppression;
8. suppression de fil depuis le bouton Supprimer supérieur;
9. double-clic physique sur interrupteur, bouton-poussoir et disjoncteur;
10. mesures tension/courant non nulles sur un circuit valide;
11. TP professeur → publication → démarrage → élève → diagnostic → réparation →
    soumission → note → clôture → lecture seule;
12. synchronisation LAN et accès élève navigateur/QR;
13. EIE visible professeur, absent comme coach élève, silencieux sans anomalie;
14. Bibliothèque de schémas : 2 cartes V2 visibles et ouverture réelle dans le simulateur;
15. Bibliothèque de pannes : 2 pannes autonomes visibles et lancement réel du circuit fautif;
16. recherche/filtres des bibliothèques et absence de fuite de la vérité professeur.

Après réussite réelle de cette checklist, le marqueur de clôture est :

`F18_PHYSICAL_MAC_PASS`

## Règle de fermeture

- `F18_G12_AUTOMATED_QUALIFICATION_PASS` signifie que le candidat est prêt au test physique.
- `F18_PHYSICAL_MAC_PASS` signifie que G12 et F18 sont définitivement fermés.
- Aucun développement post-V2 ne commence avant le second marqueur.
