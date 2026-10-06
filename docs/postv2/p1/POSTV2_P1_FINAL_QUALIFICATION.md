# Post-V2 P1 — Qualification finale

## Base produit qualifiée

La qualification finale P1 est construite sans modification du code produit à
partir du SHA d'intégration :

`b9a3cc68e95635e8ab48a313bb8f57b694eb6955`

Ce SHA a déjà passé :

- `Post-V2 P1 engine hardening` ;
- `F18-G11 Tests and automatic audits` ;
- G7 Instruments/Properties ;
- G8 TP professeur/élève ;
- G9 EIE interne.

## Portée

La qualification finale revalide les contrats P1.1 à P1.6, l'application
Flutter et produit un build macOS Release sur runner Intel. Le binaire doit
contenir l'architecture `x86_64`.

Aucun schéma ou scénario de panne supplémentaire n'est créé dans ce lot.

## Validation physique requise

Le marqueur `POSTV2_P1_PHYSICAL_MAC_PASS` reste interdit tant que le candidat
n'a pas été testé sur le Mac cible.

Les essais physiques portent sur :

1. connexions CC sans interdiction arbitraire de polarité ;
2. associations série 12+12, 24+12 et trois sources ;
3. sources opposées et point milieu ;
4. parallèle compatible sans singularité ;
5. parallèle incompatible diagnostiqué comme conflit de sources ;
6. résistance et lampe non polarisées ;
7. diode/LED directe et inverse ;
8. inversion du sens moteur CC ;
9. bobine CC simple réversible ;
10. comportement explicite des équipements PV en inversion ;
11. EIE passif, sans correction silencieuse ;
12. absence de NaN/infini et stabilité générale des mesures.

Marqueur automatisé :

`POSTV2_P1_AUTOMATED_FINAL_PASS`

Marqueur physique attendu après essai utilisateur :

`POSTV2_P1_PHYSICAL_MAC_PASS`
