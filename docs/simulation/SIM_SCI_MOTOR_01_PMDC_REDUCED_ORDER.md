# SIM-SCI MOTOR-01 — moteur CC à aimants permanents, ordre réduit

État : implémenté sur branche de qualification ; ne constitue **pas** un étalonnage constructeur. Les moteurs triphasés et l'inductance d'induit font l'objet de travaux ultérieurs.

## Domaine physique

Moteur CC à aimants permanents en convention récepteur, bornes + et −, courant positif entrant au +. Le rotor possède une vitesse signée ω (rad/s). Hypothèses : excitation constante, inductance d'induit L négligée, constantes Ke et Kt exprimées en unités SI, couple de charge externe Tload signé et frottement visqueux b. Pas de commutation ni d'arc. Le comportement transitoire de courant à l'échelle L/R **n'est pas revendiqué**.

Équations :

- **Électrique :** U = R I + Ke ω.
- **Mécanique :** J dω/dt = Kt I − bω − Tload.
- **Énergie :** P électrique = U I ; pertes cuivre = R I² ; puissance électromagnétique convertie = Ke ω I ; mécanique = Kt ω I, lorsque Ke et Kt sont cohérents en SI.

Paramètres canoniques : resistanceOhm (R), motorBackEmfVPerRadS (Ke), motorTorqueNmPerA (Kt), motorInertiaKgM2 (J), motorFrictionNmPerRadS (b), motorLoadTorqueNm (Tload). L'état vitesse et la durée du pas sont injectés uniquement dans la projection électrique du RuntimeSnapshot, jamais dans les données de conception ni la sauvegarde.

## Intégration dans le solveur nodal

Backward Euler couplé au réseau pour dt > 0 :

D = J/dt + b

R_effective = R + Ke×Kt/D

E_effective = Ke×((J/dt)×ω_previous − Tload)/D

I_new = (U_new − E_effective)/R_effective

ω_new = ((J/dt)×ω_previous + Kt×I_new − Tload)/D

Pour dt = 0, ω reste figée et la branche obéit à U = R I + Ke ω sans intégrer la durée. Le réseau reçoit une conductance 1/R_effective et une source Norton orientée à contre-EMF ; ce n'est ni un solveur indépendant ni un courant inventé après résolution.

Les branches en circuit ouvert conservent le rotor par inertie et frottement ; un rotor non alimenté peut continuer à tourner. L'état est transmis par ComponentId, préservé lors de mises à jour de paramètres à circuit identique, et remis à zéro avec ResetDynamics.

## Profil générique pédagogique

Lorsqu'aucune fiche fabricant n'est fournie, les valeurs par défaut sont R=8 Ω, Ke=0,1 V·s/rad, Kt=0,1 N·m/A, J=0,01 kg·m², b=0,002 N·m·s/rad et Tload=0 N·m. Elles sont illustratives : elles ne correspondent à aucune référence moteur industrielle déterminée.

## Validation de référence

- 24 V sur 4 Ω, ω initiale nulle : **I(0) = 6 A**.
- Pas implicite de 1 s avec Ke=Kt=0,1, J=0,01, b=0,002 : I(1 s) ≈ 4,9655 A et ω(1 s) ≈ 41,379 rad/s.
- Après 20 pas de 1 s, ω tend vers ≈133,33 rad/s et I vers ≈2,667 A.
- Test de restauration : ResetDynamics → ω=0, courant de démarrage de nouveau 6 A.
- Paramètres invalides (inertie négative, résistance non positive, NaN) sont rejetés. Préserver les résidus de KCL.
- Les solveurs AC1/AC3 refusent la loi motorDc : l'inductance équivalente d'un moteur triphasé n'est pas substituée au modèle CC.

## Réserves à lever avant label « moteur réel »

1. Ajouter L dI/dt, condition initiale du courant, démarrage, blocage mécanique, frottement sec et courbes couple-vitesse constructeur ;
2. Enrichir les propriétés et l'animation du rotor par la vitesse calculée (l'animation actuelle n'est pas un tachymètre) ;
3. Mesurer le couple, la vitesse, l'énergie mécanique et les pertes ; valider chauffage/enveloppes constructeur ;
4. Tester inversions de polarité et de couple, freinage régénératif, protections, alimentation non idéale, plusieurs moteurs et pas temporels hétérogènes ;
5. Étendre la qualification aux moteurs AC3 et aux modèles avec glissement réel.

Aucune revendication de conformité IEC ou de prédiction constructeur ne doit découler de ces seuls calculs.
