# ElectroSim — Programme PNEU-DIR-001

État technique au 11 octobre 2026. Ne pas assimiler **fusion de lots**, 
**qualification de sous-scénarios** et **livraison conforme à l'intégralité du directeur**.

## Branches et provenance

- Staging : `feat/g5-industrial-geometry-20261009` ; `main` inchangée par le programme.
- PR fusionnées dans G5 : #79 (R0), #81 (R1), #83/#85/#86/#89 (R2),
  #87/#88/#91 (R3/A–C), #93 (compatibilité Web), #92 (R3/D–E, R4/A, R5/A–B).
- La PR #94 a synchronisé la base G5 dans #92 avant sa qualification finale.
- Fusion #92 vérifiée : `5e7b75c3d35535a9e8234bfeff63c6bf9cc5c79e`,
  18 contrôles de CI complets dont Mac Intel, Web, Chromium, R2/R3, F0–F3,
  benchmark électrique et non-régression.
- PR #95 (R6/A) en développement/qualification : bancs physiques et de
  rendu 30/100/200/400, Mac Intel, physique réelle, vérification temporelle
  PHY-07 et essai causal 24 V/5/2/B1. La PR #96 a fusionné G5 dans sa branche
  pour exécuter des contrôles sur la combinaison réellement prévue.

## Tableau de réalisation (statuts distincts)

| Lot | Code intégré | Couverture restante |
| --- | --- | --- |
| R0 | Oui | Base G5 référencée |
| R1 | Contrats pneumatiques et identités intégrés | Migration/UX complète à auditer |
| R2 | Solveur gaz, volumes, débits, vérin double effet, 5/2 intégrés | Catalogue entier du directeur (3/2, vérin simple effet, clapet calibré, etc.) non entièrement simulé |
| R3 | Couplage réel 24 V S1/K1/Y1, B1, distributeur 5/2 et temps partagé intégrés | Scénarios transitoires et diversité d'appareils à poursuivre |
| R4 | Atelier Flutter expérimental platine/schéma synchronisés | **Simulation de l'éditeur pas encore reliée à son projet arbitraire ; tige/tiroir animés, courbes, instruments physiques et ISO 1219 visuel à achever** |
| R5 | Réservoir fini, fuites, tiroir bloqué et échappement bouché | Modèles plus larges de traitement de l'air non idéal et fiches fabricant à qualifier |
| R6 | Bancs 30/100/200/400, preuve Mac Intel/Linux, widget tree réel, contrôle causality/convergence en PR #95 | **PERF-01 complet et UI-01/UI-02 toujours non qualifiés ; pas de R6_FINAL_PASS** |

## Directive de qualification

Voir `docs/pneumatics/qualification/R6/ACCEPTANCE_MATRIX.md`. Les mesures
isothermes 40 ms / 10 sous-pas sont utiles, mais **ne démontrent pas**
10 secondes d'échauffement, 3 × 60 secondes en électrique/pneumatique/mixte,
95 % des frames à 16,7 ms, p95 des clics à 100 ms, fermeture des workers,
absence de fuite d'objets, ni lancement de la simulation depuis l'atelier.

Aucune capture ni quantité de widgets ne remplace la causalité physique.
Les validations doivent toujours porter sur un SHA exact et conserver
les résultats bruts ; toute exigence non prouvée reste ouverte.

La fonctionnalité expérimentale reste désactivée par défaut pour éviter
un usage pédagogique qui présenterait les graphismes comme une
simulation physique quantifiée de tous les appareils.
