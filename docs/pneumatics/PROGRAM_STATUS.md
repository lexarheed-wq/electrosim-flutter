# ElectroSim Pneumatique / Électropneumatique — PROGRAM_STATUS
Référence : PNEU-DIR-001 v1.0 (2026-10-10). Document copié sans modification sur la branche R0.

## État vérifié (ne pas confondre intention et preuve)
| Lot | Statut | Preuve actuelle / obstacle |
| --- | --- | --- |
| R0 — Référence | **en cours** | Base G5 `054c64f` identifiée, 4 jobs G5 success au SHA de base ; tests propres et métriques R0 non encore qualifiés |
| R1 — Contrats | non commencé | R0 nécessaire, décision enveloppe de stockage et interfaces typées requise |
| R2 — Physique indépendante | non commencé | R1 requis, méthode et références R2-A à figer |
| R3 — Couplage 24 V CC | non commencé | R2 requis, événements causalement ordonnés |
| R4 — Atelier deux vues | non commencé | R1–R3 requis |
| R5 — Extension réaliste | non commencé | R4 requis ; modèles non idéaux et défauts |
| R6 — Qualification et livraison | non commencé | R4 et extensions réellement livrées ; tests Mac/Web réels |

## Références et branchement
- Dépôt : `lexarheed-wq/electrosim-flutter`.
- Base candidate électricité G5 : `feat/g5-industrial-geometry-20261009` @ `054c64f5d2c74bf9a7137c730b811968834543ee`.
- Directeur source : `docs/pneumatic-program-director-20261010` @ `8b10c9e683239e13a3186c7b4a3a944e1cac4d75`.
- Branche d'exécution documentaire R0 : `docs/pneumatic-r0-baseline-20261010`.
- Validation G5 antérieure : https://github.com/lexarheed-wq/electrosim-flutter/actions/runs/38074446746 (4 jobs success ; n'est pas une validation du lot R0).
- PR dépendantes hors base : #73 audit P2 et #78 P4, toutes deux ouvertes au repérage.

## Décisions en vigueur
ADR-P01 à ADR-P08 selon le document directeur. Aucun nouveau contrat partagé modifié. Isolation stricte du moteur électrique ; mode pneumatique **n'est pas** `ElectricalMode`.

## Critères non validés
- Toutes les exigences pneumatiques PHY-01..07, CPL-01..04, UI-01..02 et PERF-01 restent **non testées / non implémentées**.
- Les performances réelles 30/100/200/400 et budgets temporels ne sont pas mesurés.
- Les builds et les captures de G5 ne prouvent pas les fonctionnalités pneumatiques.
- Exécution autonome limitée aux contrôles effectivement possibles et aux CI déclenchées ; pas d'affirmation de validation physique sur un Mac utilisateur.

## Prochaine action du lot
Exécuter le workflow R0 au SHA du dernier commit documentaire, inspecter tous les jobs, produire la matrice de scénarios et le rapport d'écarts ; décider `qualifié` seulement sur preuves. Ne pas fusionner sans instruction explicite.
