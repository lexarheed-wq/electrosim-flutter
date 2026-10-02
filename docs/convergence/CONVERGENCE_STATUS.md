# ElectroSim — État de convergence V1 / V2

## Baseline

- Base source : F18-G3R1 recovery source.
- Commit qualifié d'origine : `f52da0acba9e93032433849756abfdea17dc442d`.
- Branche de travail locale : `f18-v1-v2-convergence`.

## M0 — terminé localement

- contrat de convergence verrouillé ;
- schémas V1 : **0 migration** ;
- pannes V1 : **0 migration** ;
- catalogues F10/F11/F16 actuels marqués fixtures techniques, pas bibliothèque produit ;
- gate automatique M0 ajouté ;
- matrice V1/V2 créée.

## M1A — implémenté localement

- ajout de `ReceiverNominalRating` ;
- ajout de `ProtectionRating` ;
- séparation canonique `receiverNominalCurrentA` / `protectionRatedCurrentA` ;
- aucun alias legacy `ratedCurrent` / `Imax` ;
- aucun changement de schéma `CircuitState` ;
- aucun changement de solveur ou d'UI.

## Validation exécutée dans l'environnement courant

- `python3 -m unittest tools/test_convergence_m0_contract.py tools/test_convergence_m1_domain_contract.py tools/test_f18_g0_tooling.py` : **29/29 PASS** ;
- `python3 tools/f11_static_contract_check.py` : **16/16 PASS** ;
- `python3 tools/f11_security_static_check.py` : **PASS**, fuite teacher-truth = 0.

## Limite de validation

La toolchain Linux Flutter/Dart 3.38.10 / 3.10.9 n'est pas disponible dans l'environnement d'exécution courant et le téléchargement réseau du SDK est bloqué. Les nouveaux fichiers Dart M1A n'ont donc **pas encore reçu de preuve de compilation Flutter** ici. Ils sont volontairement non invasifs et doivent passer par le CI Flutter avant que M1A soit déclaré qualifié.

## Prochaine étape technique

M1B : formaliser les rôles/capacités des modèles seulement après compilation M1A, puis M2 : topologie multi-branches (protections, relais/contacteurs, appareils multipolaires) sans logique électrique dans l'UI.


## M1B — implémenté localement

- vocabulaire explicite L1/L2/L3, T1/T2/T3 et A1/A2 ;
- `ComponentModelContract` et `ComponentModelRegistry` ;
- contrats canoniques nouveaux pour interrupteurs, protections, contacteurs AC1/AC3 ;
- aucun alias automatique des noms de modèles V1 ;
- contacteur 3P canonique : trois pôles de puissance + bobine A1/A2, 8 bornes.

## M2 — implémenté localement

- `TopologyBranch` sépare structure interne d'un composant et nœuds conducteurs ;
- projection déterministe des branches multipolaires ;
- registre de modèles injectable ;
- `componentContractMismatch` pour forme de composant incohérente ;
- `componentModeMismatch` pour modèle canonique utilisé dans un domaine électrique non supporté ;
- aucun état ouvert/fermé, aucune loi électrique et aucun calcul de courant ajouté à la topologie.
