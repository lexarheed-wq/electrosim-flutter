# SIM-SCI MOTOR-02 — modèle électromécanique PMDC à deux états

Statut : contrat de conception préparatoire, **non implémenté / non validé**. Base immuable : `8344d81260a6f5ea5ac3c8d200a6a9e5679f29df`. Le modèle MOTOR-01 (R, Ke, Kt, J, b, Tload) reste fonctionnel et doit garder ses tests.

## Objectif et périmètre
Introduire l'inductance d'induit L>0 et les deux états persistants `i_A` (A) et `omega` (rad/s) dans le moteur DC, sans ajouter un second solveur physique divergent. Le solveur nodal conserve l'autorité sur les tensions, courants de branche et bilans; RuntimeSnapshot diffuse les mêmes états vers mesures, animation, EIE et propriétés.

## Équations et conventions
- La tension de branche est `u = v(+) - v(-)`; `i` positif de (+) vers (-); `omega` signé.
- `u = R i + L di/dt + Ke omega`.
- `J domega/dt = Kt i - b omega - Tload(omega)`.
- Puissance source instantanée `p_e = u*i`. Énergie magnétique `E_L=0.5*L*i*i`, énergie cinétique `E_J=0.5*J*omega*omega`; perte Joule `R*i*i`, perte visqueuse `b*omega*omega`. Avec `Ke=Kt` en unités SI cohérentes, puissance électromécanique échangée `Ke*omega*i = Kt*i*omega`. Si ces constantes diffèrent, signaler un contrat non conservatif au lieu d'affirmer un bilan physique exact.
- Le couple de charge doit avoir une convention signée, documentée et continue à vitesse nulle. Ne pas imposer un couple constant positif qui accélère artificiellement le rotor dans le sens négatif lors d'un arrêt.

## Discrétisation et couplage
Sur un pas `dt>0`, utiliser au minimum Euler implicite pour les variables couplées :
`(R+L/dt)*i[n+1] + Ke*omega[n+1] = u[n+1] + (L/dt)*i[n]`
`-Kt*i[n+1] + (J/dt+b)*omega[n+1] = (J/dt)*omega[n] - Tload[n+1]`.
Coupler le courant du moteur au système nodal (MNA) via un modèle compagnon, en résolvant simultanément i, omega et les tensions; **ne pas** calculer a posteriori un courant moteur incohérent avec KCL. Une itération de Newton amortie peut être nécessaire pour une loi `Tload(omega)` non linéaire. L=0 doit converger vers le modèle MOTOR-01, avec choix d'initialisation explicitement testé.

## Intégrité du runtime
- État canonique par ComponentId : `armatureCurrentA` et `angularSpeedRadS`, persisté entre pas, effacé à reset et supprimé lorsque le moteur disparaît du circuit.
- En pause : aucun avancement. Sauvegarde/restauration : vérifier déterminisme et absence d'énergie fantôme.
- L'inductance impose une continuité du courant et interdit toute avance géante unique (notamment la commande +24 h) lorsque dt dépasse les constantes de temps. Pas adaptatifs bornés avec budget d'exécution et avertissement si précision non garantie.
- Toute valeur non finie, L<0, R<=0, J<=0, b<0 ou dt<=0 doit recevoir un diagnostic sans corrompre le dernier état valide.
- N'introduire ni correction purement visuelle du courant ni nouvelle source d'état concurrente.

## Critères d'acceptation
1. L=0 reproduit les régressions MOTOR-01 sans modification de leurs tolérances injustifiée.
2. RL rotor bloqué, Tload=0 : `i(t)=U/R*(1-exp(-R*t/L))` à rotor maintenu immobile; le test doit vérifier le traitement physique du blocage, pas une simple animation arrêtée.
3. Inversion de polarité et freinage régénératif : courant et vitesse signés; les bilans ne créent pas d'énergie.
4. Pas 1 ms / 10 ms / 100 ms : convergence sous raffinement; comparer erreur de courant, vitesse et bilan énergétique au pas fin.
5. Démarrage sous charge, arrêt de source, rotor bloqué, circuit ouvert et remise à zéro : aucun NaN / courant instantanément discontinu quand L>0.
6. Réseau à plusieurs moteurs et îlots : KCL, résidus numériques et énergie par moteur.
7. Comparer des solutions analytiques pour les limites RL et inertie pure; contrôle `E_initiale + integrale(p_source) - pertes - travail_charge - E_finale` avec erreur de discrétisation explicitement bornée.
8. Exécuter domaine, topologie, DC/AC, runtime/application intégrale, G11/G12 et benchmarks 100/200/400 avant fusion.

## Ordre de réalisation
A. Étendre les paramètres canoniques typés (L, initialisation des états, freinage/blocage). B. Construire le compagnon couplé dans le solveur DC. C. Connecter la mémoire des états au moteur runtime et RuntimeSnapshot. D. Afficher les mesures/diagnostics sans duplication. E. Ajouter tests analytiques et de non-régression, puis CI. F. Compiler ultérieurement macOS Intel depuis un SHA figé et remettre un candidat physique distinct; aucun PASS Mac n'est induit par ce document.

**Règle de release :** la présence de cette spécification ne clôt pas G12-RQ et ne démontre aucun comportement électromécanique nouveau.
