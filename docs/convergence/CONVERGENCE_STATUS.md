# ElectroSim — État de convergence V1 / V2

## Base et règle de migration

- Base source : F18-G3R1 recovery source.
- Commit qualifié d'origine : `f52da0acba9e93032433849756abfdea17dc442d`.
- Branche de convergence : `f18-v1-v2-convergence`.
- Schémas V1 : **aucune migration**.
- Pannes V1 : **aucune migration**.
- Les bibliothèques Schémas/Pannes produit seront reconstruites proprement en V2.
- V1 reste une référence de comportement, de tests et de lisibilité visuelle.

## Convergence implémentée

- **M0** : baseline, matrice de convergence et garde anti-migration.
- **M1** : contrats de domaine canoniques, séparation courant nominal récepteur / calibre protection.
- **M2** : topologie multi-branches et contrats de composants.
- **M3** : solveur CC, limitation réelle de courant, protections et composants palette canoniques.
- **M4** : AC1 convergé sur les branches topologiques.
- **M5** : AC3 convergé sans régression ordre de phases / équilibre / neutre.
- **M6** : surcharge récepteur et dynamique protections B/C/D, fusible, thermique.
- **M7** : mesures CC/AC1/AC3 fondées sur les solveurs.
- **M8** : PV + énergie, y compris ombrage borné et temps de simulation explicite.
- **M9** : EIE multimode fondé uniquement sur des preuves.
- **M10** : cycle TP professeur/élève, démarrage professeur, remise lecture seule, notation, LAN multi-élèves isolé par `clientId`.
- **M11** : visuels Flutter spécifiques par modèle, source commune palette/platine.
- **M12** : interface responsive, barre compacte, cinq composants rapides maximum, actions secondaires regroupées.
- **M13** : qualification finale et packaging Mac.

## Qualification M0 → M12

Workflow : `Convergence M0-M12 qualification`.

Run qualifié : `37085328795`.

Résultat : **PASS** sur :
- contrats statiques ;
- domaine ;
- topologie ;
- solveur CC ;
- solveurs AC1/AC3 ;
- mesures / états appareils ;
- PV / énergie ;
- moteur TP ;
- diagnostics EIE ;
- application Flutter et tests ciblés ;
- garde Schémas/Pannes anti-migration.

Toolchain : **Flutter 3.38.10 / Dart 3.10.9**.

## Règle de release

M13 n'est considéré final qu'après :
1. qualification plateforme F15 ;
2. build macOS release ;
3. SHA-256 du candidat ;
4. archive source du même commit ;
5. dossier de passation avec manifeste et preuves.
