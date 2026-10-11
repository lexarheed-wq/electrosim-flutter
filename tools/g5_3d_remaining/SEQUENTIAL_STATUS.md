# G5 / 26 composants 3D — développement séquentiel

Date d'origine : 11 octobre 2026.
Branche de travail unique : `feat/g5-3d-sequential-26-components`.
**INTERDICTION DE FUSION** dans G5/main avant validation humaine des **26/26 visuels et preuves PNG**. Cette interdiction inclut les PR #103 et #107.
**Preuves** : toujours fichiers PNG directs (deux vues et captures réelles Flutter), jamais envoyer de ZIP comme preuve.
**Ordre** : finir chaque composant, puis passer au suivant sans demander de validation intermédiaire.
**Qualification** : garder les essais Mac Intel et Chromium, ainsi que la campagne GitHub de qualification générale, pour la fin des 26. Les captures sont uniquement de vrais rendus logiciels, pas des images IA.
**Non-régression** : contrats de ports/sondes/TerminalId, branchements, solveur, animation, persistance et rendu de repli.

## Inventaire ordonné

| N° | Clé | Développement et preuve |
|---:|---|---|
| 01 | `instrument-voltmeter` | Voltmètre 3D et boutons existants conservés ; mesure Ω codée par source 1 V / 1 kΩ TEMPORAIRE ; réseau ouvert désormais OL explicite ; cas série/parallèle/ouvert/alimenté créés mais NON exécutés ; preuves utilisateur/qualification différées |
| 02 | `instrument-ammeter` | Boîtier Blender A/COM/fusible, commandes/sondes Flutter codées ; 5 tests Python géométriques locaux PASS ; inscriptions A/COM déplacées hors couvercle fusible, nervures déplacées hors molette, calibrage RANGE 200 mA/2 A/10 A ; outil local PNG direct vérifiant SHA/résolution ajouté ; aucun Blender/Flutter PNG exécuté ni qualifié |
| 03 | `instrument-frequency` | En attente de son tour |
| 04 | `instrument-phase-sequence` | En attente de son tour |
| 05 | `external-crusher` | En attente de son tour |
| 06 | `external-air-conditioner` | En attente de son tour |
| 07 | `external-compressor` | En attente de son tour |
| 08 | `external-freezer` | En attente de son tour |
| 09 | `external-conveyor` | En attente de son tour |
| 10 | `external-iron` | En attente de son tour |
| 11 | `external-mixer` | En attente de son tour |
| 12 | `external-computer` | En attente de son tour |
| 13 | `external-pump-3p` | En attente de son tour |
| 14 | `external-pump-ac1` | En attente de son tour |
| 15 | `external-solar-pump` | En attente de son tour |
| 16 | `external-refrigerator` | En attente de son tour |
| 17 | `external-refrigerator-dc` | En attente de son tour |
| 18 | `external-tv` | En attente de son tour |
| 19 | `external-fan-ac1` | En attente de son tour |
| 20 | `external-fan-3p` | En attente de son tour |
| 21 | `pv-resistive-load` | En attente de son tour |
| 22 | `source-ac3-grid` | En attente de son tour |
| 23 | `source-ac3-alternator` | En attente de son tour |
| 24 | `load-wye-3p` | En attente de son tour |
| 25 | `load-delta-3p` | En attente de son tour |
| 26 | `impedance` | En attente de son tour |

## Méthode par appareil
Recette Blender originale → front et perspective palette → composants interactifs, bornes/sondes → raccordement solveur/runtime → tests locaux → PNG Flutter réel → passer à l'élément suivant. **Ne pas fusionner**, même si des tests techniques sont verts. Ne jamais compter une recette non rendue comme un visuel validé.

### Observations d'environnement
Sur le poste de développement de cette conversation, ni Flutter/Dart ni Blender ne sont installés. Les tests de la branche séquentielle sont rédigés mais n'ont pas été exécutés localement. La qualification de ces sources et les PNG réels seront produits sur les runners finaux ; ne jamais afficher une illustration IA comme preuve de capture Flutter.

### Rapport ponctuel — 11/10/2026 (session)
- Ordre strict : composant 01 traité au niveau du code, composant 02 ampèremètre en développement ; composant 03 non ouvert.
- Composant 01 : injection électrique Ω 1 V / 1 kΩ sur copie déconnectée, refus de toute source et d'élément actif, préflight réseau ouvert OL ; tests ajoutés mais NON exécutés.
- Composant 02 : recette Blender A/COM/fusible, loader et rendu face/3-4 conditionnels, fonctions HOLD/RANGE/SELECT/LIGHT, cordons souples de sondes, tests non exécutés.
- Contrat de construction : photo de référence à trois douilles, modèle logiciel ampèremètre à deux ports de mesure A/COM ; divergence documentée sans inventer de troisième borne.
- État global : 0 fusion, 0 nouveau PNG Flutter/Blender qualifié pendant cette session, pas de lancement de qualification générale ; Mac Intel et Chromium reportés.

### Avancement supplémentaire — composant 02
- Ajout d'un essai électrique théorique de l'ampèremètre en série avec la charge 24 V / 24 Ω et la résistance interne 0,01 Ω ; cas de mauvais branchement, fusible dépassé et fusible déjà coupé ; aucun test exécuté dans cet environnement.
- LCD de l'ampèremètre projeté selon les coordonnées de SA géométrie Cycles (et non celles du voltmètre) ; test de cadrage/zoom écrit.
- Affichage en palette compacte conditionné au chargement des **assets originaux** de l'ampèremètre, afin de ne pas qualifier l'ancien visuel comme 3D.
- Référence de construction : `instrument_ammeter_construction.json` ; références physiques incomplètes. Aucun PNG de l'ampèremètre généré ni prétendu validé.

### Reprise autonome — étape ampèremètre 02
- Audit de la recette Cycles : l'inscription COM était située derrière la trappe du fusible (y = 116), déplacée avec A à y = 143 ; inscription `FUSE 10 A` posée sur la trappe. Les nervures centrales chevauchant le sélecteur sont déplacées sur les flancs du holster.
- **Tests Python locaux effectivement exécutés : 5/5 PASS** dans un banc de simulation des primitives Blender, vérifiant géométrie et couleurs des deux douilles, deux perçages, boutonnerie, cadrage LCD et absence de collision trappe/douilles. Pas un vrai rendu Cycles.
- Fichier de tests reproductible ajouté : `tools/tests/test_g5_ammeter_mesh_contract.py` (7 assertions de groupes avec contrat du manifeste et syntaxe du moteur Cycles) ; tous les groupes n'ont pas encore été exécutés sur l'archive GitHub exacte.
- Outil local `tools/g5_3d_remaining/render_one.py` : un appareil à la fois ; front.png + palette.png en 1120 × 1520, identité, signature PNG et SHA-256 de la recette obligatoires ; sortie **PNG directe**, aucun ZIP. Blender absent localement : **aucune image Cycles d'ampèremètre produite**.
- Gammes de courant explicites dans l'interface : AUTO, 200 mA, 2,0 A, 10 A. Les changements de calibre ne changent pas la résistance interne du solveur ; précision matérielle des calibres à qualifier.
- Point de vigilance non résolu : le signal `blownFuse` du résultat de simulation peut indiquer un dépassement sans que l'état `InstrumentInstance.fuseBlown` soit encore verrouillé de façon persistante. Ne pas qualifier un fusible déclenché comme complet sans ce verrouillage et la coupure réelle du courant.
- Aucune fusion, aucun test Mac/Chromium ni campagne GitHub générale, aucune image de qualification prétendue. Composant 03 **non commencé**.

### Audit de reprise — correction visuelle 02, avant rendu Cycles
- Corrections du script Blender : COM et A sous leurs douilles, trappe porteuse de l'inscription **FUSE** sans valeur figée ; la valeur réelle `InstrumentInstance.fuseRatingA` est dessinée dynamiquement par le painter Flutter. Les nervures du grip n'empiètent plus sur le sélecteur.
- Les quatre gammes AUTO / 200 mA / 2 A / 10 A affichent maintenant leurs valeurs réelles, pas des indices génériques (`RANGE 1`).
- La palette du composant 02 réutilise la prévisualisation 3/4 agrandie du voltmètre lorsque ses propres images Cycles sont chargées ; ancienne clé de tooltip voltmètre conservée pour ne pas casser ses tests.
- Outil local de rendu isolé `render_one.py` : contrôle **intégral** des chunks/CRC du PNG et des dimensions 1120×1520, identité et empreinte SHA-256 ; ne produit ni ZIP ni faux rendu si Blender absent.
- 5/5 tests structurels Python exécutés localement sur la recette de géométrie de l'ampèremètre et PASS ; le contrôle de CRC a été exécuté localement sur un PNG Flutter antérieur authentique et PASS. **Aucun nouveau PNG ampèremètre** dans cette étape.
- Limite maintenue : aucun test Dart/Flutter ou Blender Cycles courant exécuté ici faute d'outillage local. Statut de l'ampèremètre = **source en progression, visuel et fusible non qualifiés**. Prochain composant (03) non ouvert.
