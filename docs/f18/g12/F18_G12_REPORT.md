# F18 — G12 Qualification finale et candidat Mac Intel

## Objectif

G12 qualifie le candidat final F18 sans modifier le code produit déjà validé par G11.
La base produit de référence est le SHA d'intégration G11 :

`3bb6d7368cf32351843afb8f35440dc65e129c35`

Toute modification après cette base est limitée au contrat, au rapport et au workflow G12.

## Qualification automatisée

Le workflow G12 doit produire sur un SHA unique :

- contrat G12 et audit transversal G11;
- Flutter 3.38.10 / Dart 3.10.9;
- `flutter analyze` de l'application;
- suite Flutter complète de l'application;
- tests explicites LAN professeur/élève et TP;
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
13. EIE visible professeur, absent comme coach élève, silencieux sans anomalie.

Après réussite réelle de cette checklist, le marqueur de clôture est :

`F18_PHYSICAL_MAC_PASS`

## Règle de fermeture

- `F18_G12_AUTOMATED_QUALIFICATION_PASS` signifie que le candidat est prêt au test physique.
- `F18_PHYSICAL_MAC_PASS` signifie que G12 et F18 sont définitivement fermés.
- Aucun développement post-V2 ne commence avant le second marqueur.

## Vague G12-RQ du 8 octobre 2026

**Source gelée** : `3bb6d7368cf32351843afb8f35440dc65e129c35`, branche
`work/rq-closure-20261008` après intégration des anomalies Mac,
CORE-UNIFY, SOLVER PV CC/AC, sauvegardes, sécurité LAN et instruments physiques.

La branche `release/g12rq-mac-test-20261008` est dérivée directement de ce
SHA. Son contenu nouveau est exclusivement ce document, le contrat G12
et son workflow final. Toute modification produit après ce gel invalide le
contrat de non-dérive et impose un nouveau cycle G11.

### Qualifications supplémentaires du candidat

- batterie 48 V autonome : SOC cohérent, décharge temporelle, arrêt à minSOC ;
- lampe CC 48 V sur bus PV + MPPT + batterie sans onduleur ;
- PV hybride : puissance répartie entre lampe CC et onduleur AC ;
- routage après dépôt et déplacement hors thread UI, sans perte de câblage ;
- sérialisation des positions/rotations/trajets et isolation des sauvegardes corrompues ;
- instrument physique voltmètre et ampèremètre sur platine avec sondes et
  mesure par projection dans le solveur électrique existant ;
- rejet de l'usurpation d'une reconnexion élève LAN ;
- régressions G0-RQ à G11-RQ et tous les domaines physiques.

### Checklist complémentaire obligatoire sur Mac Ventura

14. Déposer 25 composants, puis 50/100 : pas de ralentissement bloquant,
    navigation, pan/zoom, preview, sélection et suppression fonctionnels.
15. Batterie 48 V seule + lampe 48 V : SOC affiché et fonctionnement cohérent.
16. Simuler une durée suffisante pour atteindre minSOC : la lampe s'éteint.
17. PV + MPPT + batterie + lampe CC 48 V sans onduleur : branche lamp résolue.
18. PV + MPPT + batterie + lampe CC + onduleur + récepteur AC : bilan cohérent.
19. Déposer physiquement les appareils voltmètre/ampèremètre ; leur silhouette
    doit être identique entre la palette et la platine.
20. Brancher les sondes V/COM et mesurer une tension connue ; le résultat doit
    venir du moteur, pas de l'animation.
21. Insérer l'ampèremètre dans un conducteur et comparer le courant du solveur.
22. Recharger un circuit sauvegardé : toutes les positions et sondes subsistent.
23. Ajouter/déplacer/supprimer un appareil sans perdre les fils existants.
24. Tester réseau LAN : une reconnexion sans jeton individuel est rejetée.
25. Vérifier que la palette, les propriétés et la barre d'outils restent
    fonctionnelles pendant et après les simulations chargées.

### Conditions de sortie

`F18_G12_AUTOMATED_QUALIFICATION_PASS` autorise **uniquement la fourniture
d'un candidat Mac de test**. L'approbation sur le Mac physique de l'utilisateur
doit ensuite produire `F18_PHYSICAL_MAC_PASS`. Tant que ce marqueur physique
n'existe pas, G12 n'est pas définitivement fermé et P1 post-V2 ne commence pas.
