# Platine métallisée réintégrée dans G5

La vue Platine utilise une tôle gris argent satiné : grain horizontal discret,
reflets doux, bord fin et fixations. Sans armoire, la feuille s'adapte à
l'implantation ; avec armoire, elle occupe la surface intérieure définie par
les dimensions du coffret. Le matériau suit le pan et le zoom. Rails et goulottes
restent au-dessus de la tôle. Les croisements de fils reprennent le même fond.

La vue Schéma garde son fond blanc. Aucune borne, taille de composant, géométrie
persistée ni règle électrique ne change. Les composants sont ceux de la G5
actuelle, sans réintroduire d'anciens assets.

Voir [l'audit de conservation](../qualification/G5_INTEGRATION_AUDIT_20261012.md)
et `packages/electrosim_canvas/test/metal_mounting_plate_test.dart`.
Les captures de qualification proviennent des widgets actuels et enregistrent
le SHA source ; les anciennes captures de la PR #63 ne sont pas réutilisées.
