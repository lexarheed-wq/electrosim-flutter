# PNEU-DIR-001 — R2/R3 Scientific Preparation (DRAFT, NOT STARTED)
Date : 2026-10-10. Prérequis bloquants : R0 qualifié puis R1 qualifié. Document préparatoire uniquement.

## R2 — moteur pneumatique indépendant
Package `packages/electrosim_pneumatic_solver/` (Dart pur). Ne pas importer Flutter, stockage, canvas, son ou moteur électrique. Dépend uniquement du domaine pneumatique figé en R1.

### État et unités
- SI en interne : pression **absolue** Pa, masse kg, volume m³, longueur m, temps s, température K, débit massique kg/s, vitesse m/s.
- Atmosphère 101325 Pa ; gaz parfait sec `R=287.05 J/(kg K)`, initialement isotherme `T=293.15 K`.
- Volumes : `p_abs V=m RT`, `dm/dt=Σ m_dot`; chambres du vérin `V_A=Vdead_A+A_piston*x`, `V_B=Vdead_B+A_rod_side*(stroke-x)`.
- États garantis finis : `p_abs>0`, `m>=0` avec tolérance numérique déclarée, `V>0` ; aucune remise à zéro silencieuse après invalidité.
- Nl/min = `m_dot * R * 273.15 / 101325 * 60000`, avec conditions visibles en UI. Ne pas confondre bar relatif et absolu.

### Modèle d'écoulement R2-A à décider avant code
Première proposition indépendante : passage générique à aire effective A et `Cd`, flux quasi stationnaire isentropique entre volumes isothermes. Avec pression amont `pu`, aval `pd`, `r=pd/pu`, `gamma=1.4` (paramètre documenté), rapport critique `rCrit=(2/(gamma+1))^(gamma/(gamma-1))` :
- Si `r>rCrit`, `m_dot=Cd*A*pu*sqrt(2*gamma/(R*T*(gamma-1))*(r^(2/gamma)-r^((gamma+1)/gamma)))`.
- Sinon `m_dot=Cd*A*pu*sqrt(gamma/(R*T))* (2/(gamma+1))^((gamma+1)/(2*(gamma-1)))`.
- Si `pu==pd` : débit zéro. Si le passage est réversible, échanger amont et aval avec inversion du signe. Si clapet, appliquer pression d'ouverture et blocage inverse.
- **Important** : ce modèle de tuyère est une hypothèse générique, **pas** une certification ISO 6358. ISO 6358-1:2013 distingue notamment les coefficients `C,b,m,Δpc` ; utiliser l'expression ISO exacte et des paramètres mesurés si le modèle ISO est choisi. Ne jamais renommer l'aire effective en conductance ISO sans conversion prouvée.
- Les pertes de tuyaux et volumes concentrés exigent une fiche séparée ; interdiction de les remplacer par la distance entre points de dessin.

Références consultées le 2026-10-10 :
- NASA Glenn, équations de débit compressible et étranglement sonic : https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/mass-flow-rate-equations/
- Aperçu ISO 6358-1 et ses quatre paramètres : https://gso-sims-preview-doc-aws.s3-eu-west-1.amazonaws.com/gso-iso-6358-1-2016-en.html
- ISO 6358-1:2013/Amd 1:2020, conductance effective : https://www.iso.org/standard/75902.html

### Vérin et butées
- `Ap=pi*D^2/4`, `At=pi*d^2/4`, `Ar=Ap-At`.
- `F=(pA_abs-pAtm)*Ap-(pB_abs-pAtm)*Ar`. Calcul de `accel=(F-Fload-Ffriction)/mass` ; masse et frottements configurés, sans coefficient constructeur inventé.
- `dx/dt=v`, `dv/dt=accel`. Butées `0<=x<=stroke` gérées comme événements discrets localisés avec impulsion/énergie dissipée ou restitution documentée, pas un clamping esthétique.
- Test indépendant PHY-01 : D=0.032 m, pA_rel=600000 Pa, pB_rel=0 : `F=482.5486316 N`; tolérance directeur ±0.5 N.
- Limite sous-charge/charge excessive : position stagne ou retourne suivant la dynamique, jamais trajectoire prédéterminée par animation.

### Intégrateur, stabilité et bilans (R2-A)
- Évaluer au préalable solveur adaptatif conservatif / événementiel contre référence indépendante ; sélectionner tolérance relative ET absolue avant les tests de qualification, pas après un FAIL.
- Variables physiques agrégées dans `PneumaticRuntimeSnapshot` immuable versionné, incluant pression, masse, débit, v, x, F, qualité résultat, temps accepté.
- Bilans : fermé masse conservée à ≤1e-6 relatif sur 10s (PHY-02) ; ouvert erreur relative ≤0.1% avec normalisation et seuil absolu publiés (PHY-03).
- Vérifier étranglement et inversions sans singularité (PHY-04), restriction et clapet (PHY-05), dynamisme et butées (PHY-06), réduction de pas/tolérance et événements à ≤1% normalisé (PHY-07).
- Source R2 idéale explicitement identifiée, réservoir/compresseur/régulateur non idéal uniquement R5.

## R3 — couplage électrique 24 V CC
R3 part du couplage **explicite** figé en R1 ; aucune inférence par nom visuel.
- Séquence d'horloge unique : (1) résolution électrique aux contacts actuels ; (2) évaluation tension aux bobines ; (3) avance masse/pression/mécanique jusqu'au premier événement ; (4) mise à jour capteurs ; (5) re-solve électrique à temps zéro. Pas de double avancée physique lors de (5).
- Sur bobines : tension réelle, prise/retombée, hystérésis, délai éventuel ; 5/2 monostable retour ressort, 5/2 bistable mémorise sa dernière position si aucune commande ; règle d'opposition documentée.
- Contact de capteur NO/NC suivant position, zone et hystérésis. Ne pas simuler PNP/NPN sans modèle.
- Référence de recette : S1 NO ∥ K1 NO → B1 NC série → relais K1 et bobine Y1 ; 5/2, vérin double effet, fin de course B1. Tester explicitement S1 bref et S1 maintenu (ce dernier peut répéter).
- Coupure 24 V ne vide pas l'air ; fermeture d'alimentation ne met pas automatiquement toutes les chambres à l'échappement.
- Événements simultanés ordre déterministe ; rebouclages à temps nul bornés, rollback du dernier état accepté et diagnostic non-convergence.
- Cas CPL-01..04 doivent être démontrés par journaux horodatés et courbes physiques réellement calculées.

## R4 — atelier et performances
- Deux layouts indépendants, objets identiques. Platine frontal / palette perspective ; schéma ISO 1219 / électricité IEC avec vérification de la représentation.
- Ports et tuyaux cliquables, repères 1/P,2/A,4/B,3/R,5/S; pression et débit distincts (flux nul ne s'anime pas).
- Animations interpolées entre snapshots acceptés, jamais sources de vérité.
- Exécution hors thread UI sur natif avec isolate persistant ; worker Web réellement hors thread UI, protocole révision projet + numéro de demande, invalidation sélective, file bornée.
- Qualification UI-01/02 et PERF-01 selon protocole 30/100/200/400 du directeur ; aucune image créée artificiellement ne constitue une preuve de produit.

## R5 — composants/physique étendue
- Réservoir, compresseur, régulateur non idéal, fuite, tuyau écrasé/bouché, échappement bouché, tiroir grippé, bobine en défaut.
- Chaque modèle autonome dispose d'une fiche (unités, hypothèses, limitations et références) et tests comparatifs indépendants.
- Enrichissement par lots isolés ; aucun changement implicite du solveur électrique.

## R6 — qualification finale
- Matrice PHY/CPL/REG/ERR/UI/PERF/BUILD complète au SHA intégré, régression électrique, Web et Mac Intel **compilés et réellement lancés**, benchmarks bruts et reproductibles.
- Documents v0/v1/v2, export aller-retour, deux vues, annuler/rétablir, erreurs de worker, ressources libérées, volumes/pièces mobiles et contrôles causaux.
- Aucun « terminé », « intégré » ou release avant la qualification sur le commit final. Fusion seulement sur instruction explicite de l'utilisateur.

## Réserve de gouvernance
Ce texte est une **préparation**, pas une validation scientifique R2-A ni une implémentation R1–R6. Les signatures et tolérances finales doivent être figées à l'entrée du lot et enregistrées dans les décisions avant tout code.
