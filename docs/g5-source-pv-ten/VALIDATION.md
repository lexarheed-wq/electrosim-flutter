# Validation du lot sources et photovoltaïque — 11 octobre 2026

Branche locale : `feat/g5-source-pv-ten-20261010`, base `a8c21b4`.
Dix géométries originales, quatorze entrées du catalogue avec variantes.

## Résultats observés

- Suite application complète : 557 tests réussis, deux ignorés faute de configuration du parcours navigateur réel. Exécution avant le déplacement final de l’action du bornier dans les propriétés.
- Canvas : 107 tests réussis, dont la sélection de la borne la plus proche à faible zoom.
- Après déplacement de l’action : 23 tests de régression réussis (propriétés, interface responsive, commandes, migration et composants).
- Tests dédiés des dix équipements, du dialogue et de son écran compact réussis (5).
- Analyse Flutter de l’application après déplacement : aucune anomalie.
- Compilation Web release finale après déplacement : réussie (56 secondes).
- Capture du vrai workspace F18 par test Flutter : réussie, onze images. Le clic des propriétés ouvre effectivement le bornier arrière et sa fermeture fonctionne.
- Garde architecturale CORE_UNIFY et contrat POSTV2_P1 : réussis.
- Revue de code indépendante : aucun bloqueur identifié ; contrôle du diff sans erreur d’espacement.

## Corrections vérifiées

Les MPPT/PWM ont leurs quatre bornes en bas, la batterie ses cosses en haut. Les sources utilisent des prises creuses, la batterie des lames Faston. Le panneau dispose d’un boîtier arrière avec contacts, diodes de dérivation et deux sorties électriques. Les contacts intérieurs illustrent la construction ; ils ne créent pas de nouvelles bornes de simulation.

La migration conserve les rails, placements, rotations, ancres personnalisées et connexions électriques. Elle retire seulement les anciens offsets PV reconnus et invalide les routes devenues incompatibles. Le clic choisit la borne la plus proche lorsque les zones de clic se recouvrent.

## Preuves et limites

Les captures de `proof/2026-10-11-native-contacts/` viennent des widgets de production dans un test Flutter, pas d’une maquette. Le manifeste contient leur SHA-256. Les photos commerciales servent de références documentées et ne sont pas redistribuées comme textures produit.

Ce lot ne qualifie ni la performance à 400 composants ni une compilation macOS. Le rendu reste une représentation originale, sans garantie d’identité photographique à 100 %. La platine métallique est un chantier distinct. Aucun push ni fusion GitHub de ce lot n’a été effectué.

Si les assets ne peuvent être chargés, le rendu général garde son repli ; l’inspection du bornier arrière peut afficher une image absente. Ce cas reste à améliorer.
