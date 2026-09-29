# F9 — Contrat UX validé à préserver

**Statut : préparation uniquement. F9 n'est pas ouverte tant que `F8_GATE_PASS` n'est pas obtenu.**

Ce document fige les décisions UX déjà validées afin d'éviter que la refonte Flutter ne réintroduise des parcours contradictoires. Il décrit les comportements et la structure attendus, pas l'implémentation.

## 1. Accueil principal

L'accueil expose exactement trois entrées de premier niveau :

1. **Créer une nouvelle session** — préparer une activité et connecter les élèves.
2. **Centre de maintenance** — bibliothèque de pannes/scénarios de dérangement et recherche de dérangement.
3. **Centre de conception** — câblage et bibliothèque de schémas sains/fonctionnels.

L'accueil peut conserver une identité visuelle de marque plus expressive que le workspace, mais il ne doit pas masquer la hiérarchie des trois actions principales.

## 2. Session active

Dès qu'une session existe, la navigation persistante propose :

- **Accueil** ;
- **Tableau de bord** ;
- **Gérer la session**.

Le tableau de bord professeur regroupe trois espaces métier :

- **Câblage** ;
- **Recherche de dérangement** ;
- **Supervision**.

Une branche déjà choisie ne repropose pas inutilement le choix Câblage / Recherche de dérangement à l'intérieur du même parcours.

## 3. Rôles professeur / élève

Le noyau et le Canvas sont communs ; les politiques d'accès et les panneaux visibles diffèrent.

### Professeur

- crée/prépare/publie les activités ;
- supervise progression, mesures, tentatives, validation et résultats ;
- accède aux vérités pédagogiques nécessaires uniquement dans les vues professeur ;
- peut gérer la session sans fermer le simulateur.

### Élève

- ne reçoit jamais `teacherTruth` ni une correction privée ;
- ne voit pas les actions professeur ;
- après fin/validation d'un TP, l'activité devient **lecture seule** avec résultats consultables ;
- la fiche de diagnostic n'existe dans son interface **que pendant une Recherche de dérangement**.

## 4. Câblage

- le simulateur est la surface dominante ;
- la palette n'affiche que des éléments pertinents au contexte ;
- les exemples sont exclusivement des circuits sains et fonctionnels ;
- clic composant = sélection sans déplacement ;
- appui long + glisser = déplacement ;
- borne → borne = câblage ;
- le visuel ne décide jamais l'état électrique.

## 5. Recherche de dérangement

- un TP charge directement un `FaultScenario` autonome déjà défectueux ;
- la fiche de diagnostic est un panneau élève contextuel et repliable ;
- les outils de mesure restent accessibles ;
- le défaut réel reste privé ;
- la réparation est validée par recalcul topologique, électrique et fonctionnel.

## 6. Mobile

- le Canvas reste prioritaire ;
- aucun panneau permanent ne doit réduire le Canvas à une bande étroite ;
- palette, propriétés, diagnostic et EIE s'ouvrent en tiroirs / sheets ;
- les actions principales restent accessibles sans scroll horizontal ;
- toutes les zones essentielles doivent être atteignables tactilement.

## 7. Règles non négociables

- aucune fonctionnalité électrique n'est créée uniquement pour faciliter l'UI ;
- aucun état `running`, `faulted`, `energized`, etc. n'est déduit d'un bouton ou d'une animation ;
- état UI (`selected`, `hovered`, `focused`) et état électrique restent séparés ;
- les couleurs de marque ne remplacent pas les codes de phase/polarité ;
- la cohérence palette ↔ platine est obligatoire ;
- F9 ne modifie pas les contrats F1→F8.
