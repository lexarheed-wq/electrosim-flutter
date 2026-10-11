# G5 / 26 composants 3D — lots de 10, vérifications par composant

Date d'origine : 11 octobre 2026.
Branche de travail unique : `feat/g5-3d-sequential-26-components`.
**INTERDICTION DE FUSION** dans G5/main avant validation humaine des **26/26 visuels et preuves PNG**. Cette interdiction inclut les PR #103 et #107.
**Preuves** : toujours fichiers PNG directs (deux vues et captures réelles Flutter), jamais envoyer de ZIP comme preuve.
**Organisation actualisée par le chef de projet** : lots de 10 (01–10, 11–20, puis 21–26). Chaque composant conserve ses contrôles propres ; recherches photo regroupées par lot. Aucun développement parallèle imposé. Modèles actuellement commercialisés recherchés chez les fabricants ; date de téléchargement et date du modèle distinguées.
**Qualification** : garder les essais Mac Intel et Chromium, ainsi que la campagne GitHub de qualification générale, pour la fin des 26. Les captures sont uniquement de vrais rendus logiciels, pas des images IA.
**Non-régression** : contrats de ports/sondes/TerminalId, branchements, solveur, animation, persistance et rendu de repli.

## Inventaire ordonné

| N° | Clé | Développement et preuve |
|---:|---|---|
| 01 | `instrument-voltmeter` | Voltmètre 3D et boutons existants conservés ; mesure Ω codée par source 1 V / 1 kΩ TEMPORAIRE ; réseau ouvert désormais OL explicite ; cas série/parallèle/ouvert/alimenté créés mais NON exécutés ; preuves utilisateur/qualification différées |
| 02 | `instrument-ammeter` | Modèle Cycles A/COM/fusible et commandes Flutter ; 5 tests Python géométriques PASS antérieurs ; surcharge fuse désormais verrouillée dans l’instrument et liaison coupée uniquement dans la topologie runtime ; trappe avec remplacement explicite OFF/circuit sans source ; tests Dart rédigés NON exécutés ; rendu Blender/PNG ampèremètre non produit, NON qualifié |
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

### Rapport de développement — fusible de l’ampèremètre (11/10/2026)
- `runtime/f18_ammeter_fuse_safety.dart` : contrôle de l’insertion série réelle A/COM, verrouillage `InstrumentInstance.fuseBlown` uniquement sur surcharge confirmée par `ElectroSimInstrumentProjection`, conservation des sources/composants/fils/sondes dans le circuit sauvegardé.
- `ElectroSimRuntimeEngine.advance` applique `projectOpenFuses` à ses DEUX chemins de résolution (premier calcul et recalcul de panne), en désactivant uniquement la liaison série concernée dans la copie effective, **sans toucher au circuit utilisateur**.
- `F18WorkspacePage` programme le verrouillage **après la frame Flutter** plutôt que de faire `setState` pendant un rendu, annule toute répétition via un ensemble de fusibles en attente et relance le solveur sur la révision actualisée.
- `F18AmmeterControls` et le lecteur d’instruments affichent `FUSE` même sélecteur sur OFF ; aucun changement de mode ne remet un fusible déclenché en état.
- Trappe de fusible séparée de la molette (sélecteur déplacé de y=91 à y=86, hit map de diamètre 40). Un clic ouvre une boîte de confirmation **uniquement** pour remplacement lorsque l’instrument est éteint, toutes les sources supprimées et le circuit composé exclusivement d’éléments résistifs connus. Les changements sont revérifiés après confirmation.
- `test/g5_ammeter_fuse_runtime_test.dart` : tests écrits de surcharge 24 V/24 Ω avec calibre 0,5 A, absence de déclenchement pour 10 A, état persistant via sérialisation, coupure électrique en `effectiveCircuit`, mauvaise connexion, conservation des fils enregistrés, remplacement interdit sous tension et remis à zéro en condition sûre. **NON EXÉCUTÉS**, Dart/Flutter non disponible localement.
- Les cas d’ampèremètre existants (boutons, gammes, molette, LCD, sources/résistance interne) ne sont pas encore requalifiés. Les 26 composants restent **sans nouvelle fusion**, pas de lancement de la campagne CI ou de Mac/Chromium. **Aucun PNG d’ampèremètre encore généré.**
- Limite technique : l’ampèremètre non déclenché est mesuré avec sa résistance interne dans une projection de mesure série, tandis que la résolution globale du circuit normal n’inclut pas encore systématiquement cette résistance interne. Ne pas présenter cela comme parité physique intégrale avant correction spécifique et tests.

### Décision confirmée — ampèremètre et pince distincts
- Le chef de projet valide l'ampèremètre **à cordons A/COM, en série** comme composant 02. La **pince ampèremétrique** reste un instrument de type `InstrumentKind.clampAmmeter` indépendant, à développer séparément sans changer arbitrairement l'inventaire verrouillé des 26.
- Code supplémentaire : `ElectroSimRuntimeEngine.advance` appelle désormais `F18AmmeterFuseSafety.projectDcSeriesBurden` dans les deux branches de résolution (normale et après dommage). En **CC seulement**, l'ampèremètre inséré crée une résistance de shunt `burdenResistanceOhm` dans la topologie temporaire réellement résolue. Le fil de conception conserve son ID et ses données mais est désactivé dans le circuit effectif.
- Fusible `fuseBlown` : priorité à la coupure, jamais de nouveau shunt ; la rupture reste effective même si l'un des cordons est ensuite retiré, tant que l'instrument et `cutConnectionId` existent. Deux ampèremètres assignés au même fil provoquent une défaillance électrique ouverte plutôt qu'un rétablissement silencieux du conducteur.
- Tests Dart de non-régression ajoutés (toujours **NON EXÉCUTÉS**) : résistance de shunt dans le solveur principal, courant calculé 24/(24+0,01), fusible ouvert, débranchement de sonde, collision de deux ampèremètres, et absence totale de coupure/shunt pour une pince `clampAmmeter`. Ne pas considérer ces fonctions comme qualifiées avant vraie exécution locale/Flutter.
- Distinction architecture : **une pince mesure par `InstrumentPort.clamp` sur `ConnectionId` et ne modifie pas le graphe** ; l'ampèremètre A/COM a un `cutConnectionId` et un shunt réel. Mac Intel, Chromium et campagne générale GitHub différés. Aucun nouveau PNG produit. Aucune fusion.

### Reprise exécutée — composants 01/02 (11/10/2026)
- Outillage effectivement disponible : Flutter 3.38.10/Dart 3.10.9 et Blender 4.5.3. Les mentions historiques « NON EXÉCUTÉS » ci-dessus décrivent la situation antérieure.
- 01 : tests Ω/source interdite/commandes/projection exécutés ; capture Flutter réelle 120 Ω, cordons frontaux avec poignées et pointes, textes vectoriels. Les connexions et identifiants électriques sont conservés.
- 02 : deux PNG Cycles originaux 1120×1520/96 échantillons générés, contrôlés et intégrés dans assets/g5_industrial/instrument-ammeter-{front,palette}.png.
- Correction scientifique : les LCD des ampèremètres CC lisent leur shunt dans le solveur commun, en tenant compte des autres instruments ; signe A/COM ; le voltmètre utilise la topologie effective chargée. Le fusible protège aussi l'entrée avec écran OFF.
- 42/42 tests ciblés passent, dont trois captures de l'application Flutter : courant 1,00 A (valeur solveur 24/24,01), surcharge FUSE et surcharge avec écran initialement OFF. Captures dans apps/electrosim/build/g5-sequential-proof/instrument-ammeter/workspace-{series,fuse-overload,off-input-overload}.png.
- Qualification technique de cette étape : CC et contrôles/fusible. La parité de charge commune AC/PV reste à qualifier ; ne pas revendiquer une équivalence physique intégrale pour ces modes. Mac Intel/Chromium et campagne globale restent différés. Aucune fusion ni validation humaine finale des 26.
- Prochaine étape autorisée : composant 03, fréquencemètre, suivant l'ordre séquentiel.

### Qualification locale 03 et corrections transversales (11/10/2026)
- Fréquencemètre : géométrie Cycles dédiée, deux PNG 1120×1520, chargeur atomique avec repli, boutons HOLD/ON-OFF/LIGHT et écran vectoriel. Aucun changement du contrat de ports.
- Tests : 6 contrôles/captures passent ; qualification PHYS-METER : 3 passent ; campagne ciblée instruments : 22 passent. Captures réelles 50 et 60 Hz dans `apps/electrosim/build/g5-sequential-proof/instrument-frequency/`. Après routage de la fixture par le moteur orthogonal de production, les deux captures passent à nouveau.
- Source : conducteurs de puissance marron/bleu routés orthogonalement ; cordons de mesure et pointes uniquement pour les instruments. La fixture initiale sans routes donnait un trajet direct masqué par le corps ; aucune substitution du rendu de puissance en cordons dans le moteur.
- Ampèremètre : le fil ouvert pour insertion en série ne reste plus dessiné en parallèle sur la platine. Contrat partagé `SeriesMeterWiring` entre domaine/runtime/rendu ; 27 tests ciblés passent, captures de série/fusible régénérées.
- Noms externes sous les appareils supprimés à la demande du chef de projet. Marquages physiques, bornes, mesures, palette et inspecteur conservés. Analyse Dart sans erreur ; deux captures Flutter passent après suppression.
- Limite : fréquence fondamentale des scénarios AC1/AC3, sans revendication de détection harmonique ou de mesure temporelle réelle. Composant 03 techniquement vérifié localement ; validation humaine globale et qualification Mac/Chromium différées. Aucun lot déclaré complet, aucune fusion.
