# R2-A — Hypothèses scientifiques figées, avant qualification

Programme : PNEU-DIR-001 v1.0. Ce document est une fiche de modèle testable,
pas une preuve de conformité ISO ni une déclaration d'achèvement de R2.

## Périmètre du premier sous-lot R2/A

- **Gaz :** air sec parfait, isotherme, constante spécifique R = 287,05 J/(kg·K),
  température nominale 293,15 K, gamma 1,4.
- **Unité de pression :** Pa **absolus** dans le moteur. 6 bar relatifs = 701325 Pa
  absolus pour atmosphère 101325 Pa.
- **Conservation :** volumes rigides fermés uniquement. Pour chaque chambre
  `pV=mRT`, `dm/dt=Σṁ`; un flux transféré sort du donneur et entre
  dans le receveur sur le **même** sous-pas.
- **Débit :** tuyère isentropique quasi stationnaire d'aire effective A, coefficient
  de décharge Cd, branche subsonique ou étranglée à
  `rcrit=(2/(gamma+1))^(gamma/(gamma-1))`. Retour de débit signé, usage de la
  température du donneur.
- **Débit normalisé :** Nl/min à 0 °C et 101325 Pa, avec `R=287.05`.
  Le symbole « Nl » ne désigne pas des litres comprimés.
- **Passage unidirectionnel simplifié :** débit inverse zéro, sans pression
  d'ouverture ni fuite inverse. Modèle complet du clapet prévu au lot ultérieur.
- **Intégrateur :** Euler conservatif à pas borné, pas nominal maximal de
  0,005 s, limitation supplémentaire à 20 % de la masse disponible par
  donneur et sous-pas. Arrêt explicite si nombre de sous-pas excède sa limite.
  Aucune mutation partielle du snapshot original en cas d'échec.
- **Vérin :** surfaces, volumes de chambre et force statique
  `F=(pA-patm) Ap-(pB-patm) Ar` ; pas de mouvement ou de butée
  dynamique qualifiés dans ce sous-lot.

## Référence analytique extérieure au code

`test/fixtures/r2_orifice_oracle.json` est une copie du corpus de référence
préparé avant l'implémentation. Pour A=1e-6 m², Cd=0,8, 701325 Pa et 293,15 K :
- rapport critique ~0,528281787717 ;
- débit étranglé 0,0013243594116 kg/s (61,4892585462 Nl/min) ;
- diamètre piston 32 mm et pression de 6 bar relatifs :
  force calculée attendue 482,54863159 N, tolérance 0,5 N.

Les essais comprennent les rapports 1, 0,95, 0,9, 0,8, 0,7, 0,55,
0,52828, 0,5 et 0,2, la réversibilité, une simulation fermée de
10 s, les dimensions impossibles, les références inconnues et la
limite du nombre de sous-pas. Conservation de masse relative visée :
≤ 1e-6 à 10 s pour le système **fermé**. Un bilan ouvert avec source
d'air reste hors du sous-lot.

## Limitations bloquantes avant de déclarer R2 « terminé »

- Raccord du solver indépendant au `PneumaticNetwork` de R1 avec ports
  canoniques, valeurs d'aire/longueur/diamètre et traitement des tés.
- Clapet non idéal (seuil, hystérésis), pertes de charge et volumes des tuyaux.
- Cylindres dynamiques (masse, vitesse, accélération, frottements, butées,
  événements exacts), sources et échappements ouverts, tests
  PHY-03/06/07 complets.
- Pas encore de `RuntimeSnapshot` de production, événements globaux, worker
  ou Web/atelier. Tests de stabilité, précision par raffinement du pas
  et benchmarks, avant fusion totale R2.
- Pas de paramètres constructeur ni de certification ISO 6358.
- Les contrôles du package Dart doivent être verts au SHA final de la PR
  puis revalidés au SHA de merge, ainsi que les non-régressions G5.
