# PNEU-DIR-001 — R3/A : liaison 24 V et horloge des événements

Date : 2026-10-10 — **sous-lot implémenté, non qualifié avant CI au SHA final**.

## Dépendance et portée
Empilé sur R2/C (PR #86). Aucune modification du solveur CC existant,
ni de `CircuitState`, ni des schémas/pannes V1. Le solveur électrique
actuel continue de déterminer le courant, les tensions et l'état des
contacts. Le nouvel adaptateur reçoit `DcSolveResult` pour le **même**
`circuitId` et la **même** révision.

## Comportements pris en charge
- Identification canonique `ElectropneumaticLink(solenoidCoil)` reliant
  le composant électrique à un dispositif pneumatique du même matériel.
- La bobine d'essai **est un résistor de 240 ohms sous 24 V** : à cette
  étape, c'est un **substitut résistif** de l'enroulement. Ce n'est PAS
  une bobine RL, ni un modèle magnétique, ni une régulation thermique.
  Le courant de 0,1 A et la puissance 2,4 W proviennent du solveur CC,
  et non de l'illustration.
- Seuils explicites de prise et retombée (valeurs de laboratoire par
  défaut 80 % et 35 % de 24 V), temporisations 20 et 10 ms. Ces seuils
  **ne prétendent pas être des valeurs constructeur**.
- Distributeur 5/2 monostable : retour ressort quand la bobine retombe.
  Bistable : mémoire de position après relâchement ; opposition de
  bobines explicite rejetée.
- Fin de course NO/NC : contact à hystérésis de position réelle, sans
  déduction depuis le dessin.
- Horloge `ElectropneumaticEventClock` : résolution électrique,
  prochain instant d'événement, **une** intégration d'air par pas accepté,
  relecture électrique à temps zéro, limite du nombre de répétitions.
  Un calcul électrique répété ne multiplie pas le pas pneumatique.
  L'horloge exige qu'un fournisseur de gaz réellement physique renvoie
  le temps accepté exact.
- Coupure du 24 V distincte d'une perte de pression : chambre isolée
  conserve la masse d'air et la pression calculées après coupure.
- Erreur d'un résultat périmé, d'une liaison non déclarée, de mesure
  incorrecte ou d'une horloge non convergente : arrêt explicite, pas de
  nouvel état de simulation accepté.

## Limites — interdiction de marquer R3 terminé sur ces seuls tests
- Bobines réelles électromagnétiques, inductance, montée du courant,
  échauffement, défauts et seuils constructeur ;
- Raccordement de tous les ports d'un 5/2 au solveur massique,
  piloter le tiroir avec son délai physique et les deux bobines ;
- Commande complète auto-maintien K1/S1/B1 sur un **circuit complet** :
  mesurer après fermeture du contact et tester S1 bref/maintenu,
  cycles, courses dynamiques et plusieurs événements rapprochés ;
- Localisation exacte des événements de fin de course entre deux
  sous-pas, ressources d'îlots multiples et annulation atomique des
  solveurs avec rollback ;
- CPL-01..04 complets exigés par le directeur et performances R6.

## Contrôles de la PR
- Le test d'entrée lit **réellement** `SolverDC` et `TopologyEngine`
  depuis un circuit 24 V, interrupteur S1 et charge Y1 240 ohms.
- Vérification du lien R1, de la puissance électrique calculée,
  d'un 10 V insuffisant, de l'identité/révision de circuit.
- Tests d'horloge, temporisations et coupure électrique vs air piégé.
- Tests d'hystérésis fin de course, positions bistables, simultanéité
  de commandes opposées et refus de feedback invalide.
- Régression de tous les tests du package scientifique R2.
- Qualification et preuves au SHA exact avant fusion et après
  intégration ; jamais forcer une CI rouge.
