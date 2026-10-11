# G5 / PR #98 — audit contradictoire des captures Mac Intel

## Provenance et diagnostic

- Fusion historique inchangée : PR #98 → branche `feat/g5-industrial-geometry-20261009`, commit `60caab5b00b5461109527f04be9b96c9881b95fb`.
- Suite Mac de la branche source PR #98 : **581 tests réussis, 9 cas de tests visuels échoués, 2 ignorés** (job `114370204830`). Pas de justification pour remplacer aveuglément les PNG.
- Source du premier contrôle réellement contradictoire : CI Mac Intel à `2de5d1a0cd5030b550d7eaf1836fb2397a4a2007`, artifact `11689658829` : **15 écarts de captures** provenant des 9 tests. Le contrôle Linux strict sur ce même commit était vert.
- Vérification par inspection des références `masterImage.png`, captures `testImage.png` et pixels `isolatedDiff.png` pour les 15 images, notamment F9 390/820/1440, interrupteurs, tableaux palette/platine G12RQ, 5/2 et disjoncteur états OFF/ON/TRIP.
- Écarts observés essentiellement dans la typographie et l'antialiasing, sans déplacement des composants, sorties, connexions ni bornes démontré par l'inspection. L'ajout de la même police DejaVu Sans 2.37 sur Mac a ramené la différence de l'image `g12rq_actual_widgets_palette_board` de **10,36 % à 0,54 %** et `g5_industrial_off_on_trip` de **5,37 % à 1,99 %**.

## Règles non négociables

1. Les **15 références Linux originales** restent **intactes** : échec immédiat à toute différence pixel dans les captures de référence sur CI Linux.
2. Sur Mac Intel, **aucune tolérance arbitraire de pixels n'est introduite**. Les 15 captures sont comparées octet par octet aux SHA-256 des 15 vraies captures inspectées (manifest `tools/g5_pr98_mac_approved_pixels.json`). Un seul octet inattendu déclenche une erreur.
3. Le pipeline Mac exige exactement **9 tests de comparaison visuelle** échouant contre les références Linux, avec **15 captures identifiées** et aucun nouveau cas. Toute régression supplémentaire est refusée.
4. La campagne complète Mac exécute tous les autres tests physiques, composants, positions de bornes, CC/AC1/AC3/PV, et exige une compilation native macOS Intel x86_64. Une anomalie scientifique ne peut jamais être considérée comme une simple variance graphique.
5. La CI Chromium/Web doit rester verte ; les screenshots de Chromium sont indépendants de la rastérisation native macOS.

**Attention :** la qualification Mac par hachage exact est attachée à Flutter 3.38.10, macos-15-intel et au paquet de police fixé. Une mise à jour du moteur de dessin peut requérir une **nouvelle inspection contradictoire**, jamais un remplacement automatique des références.

## État de livraison

Le correctif de formatage Dart et la suppression des espaces en fin de ligne ont été réalisés dans la PR #102. La fusion vers G5 reste conditionnée à la réussite complète des contrôles au commit exact. Cette note n'est pas une déclaration autonome `PASS`.
