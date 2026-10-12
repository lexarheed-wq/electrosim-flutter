# Audit de conservation des travaux G5 — 12 octobre 2026

## Base et méthode

Base examinée : `709bac5ce562fe2ee0215b58ae959c82e28bdda7` (fusion #140).
La présence d'un ancien commit dans l'ascendance ne prouve pas que ses fichiers
et comportements sont encore livrés. Cet audit combine diff des réconciliations,
fichiers actuels, contrats de géométrie, tests des widgets de production et
parcours Chromium avec serveur HTTP/WebSocket natif.

Le périmètre est le travail développé/livré pour la platine industrielle,
la représentation schématique, le catalogue, les armoires et les TP dans cette
conversation. Il ne transforme pas les exigences post-V2 restantes ou les
brouillons pneumatiques en fonctionnalités terminées.

## Pertes confirmées et corrigées

Le commit `dabe8d160137608fddbc65b73b558dffa74d6d9d` apportait la tôle satinée.
La réconciliation `5c799abe610098af47d6461a6f5720b137e89fed` a supprimé
`metal_mounting_plate.dart` et retenu le peintre de la base P3, avec quadrillage.
Les réconciliations ultérieures `7b9e13db` et `b1cfc30a` ont également conservé
cette absence par rapport à leurs parents historiques. Il ne s'agissait pas
d'une option masquée.

Restauration : même matériau satiné, grain borné et déterministe, reflets, bord
et fixations. La feuille autonome suit l'implantation ; avec armoire elle utilise
exactement la platine intérieure définie par l'enveloppe, sans feuille autonome
derrière le coffret. Les masques de croisements utilisent le matériau local.
Le schéma reste blanc et le canvas historique conserve son quadrillage.

Sept tests de pixels réels couvrent la feuille vide, le dégradé, l'armoire,
pan/zoom, le schéma blanc, le canvas historique et les croisements sur les deux
types de platine. Les tests de surfaces et de croisements ont échoué sur le
comportement perdu avant de passer avec la restauration.

La même fusion avait supprimé `g5_p2_layout_preservation_test.dart` et retiré
la copie de l'armoire dans `F18DragSession.previewAt`, dans
`provisionalConnectionLayout` (utilisé dès 30 appareils), et dans l'ancien
`F9OrthogonalRouter.reroute`. Un déplacement connecté ou un raccordement d'un
grand circuit pouvait ainsi perdre l'enveloppe, les fixtures et les montages.
Les trois chemins conservent maintenant tout le cabinet, les rotations et les
ancres de bornes. Les trois tests historiques ont été récupérés et enrichis ;
deux tests de widgets couvrent aussi un vrai glisser-relâcher et le workspace
de 30 appareils avant et après son routage asynchrone. Les pertes ont été
reproduites, puis les tests passent avec la correction.

La capture de qualification attend désormais aussi le chargement des assets
natifs récents (instruments, prises et récepteurs), afin qu'un repli transitoire
pendant leur décodage ne soit pas présenté comme le produit final.

## Travaux conservés : preuves dans le produit actuel

| Travail | Implémentation actuelle | Régressions exécutées |
|---|---|---|
| Platine/Schéma synchronisés, symboles et fond blanc | `f18_workspace_page.dart`, `industrial_workspace_representation.dart`, `CircuitScenePainter` | `industrial_representation_workspace_test`, `industrial_schematic_projection_test`, `industrial_workflow_test` |
| Rails DIN, goulottes, routage et implantation d'armoire | `cabinet_layout.dart`, `cabinet_duct_wire_planner.dart`, `industrial_cabinet_workspace.dart` | `industrial_duct_workspace_test`, `industrial_cabinet_model_test`, `industrial_cabinet_workspace_test`, `postv2_p2_cabinet_*`, suite Canvas |
| Géométrie persistante, montages, surfaces et aperçu 3D complémentaire | `electrosim_layout_persistence.dart`, `cabinet_physical_model.dart`, `industrial_workspace_representation.dart` | `postv2_p2_layout_persistence_test`, `industrial_representation_workspace_test`, `industrial_cabinet_model_test` |
| Composants industriels actuels, contacts et rendu après rotation | Assets G5 actuels et `f18_industrial_physical_plate.dart`, `f9_component_visuals.dart` | `g5_industrial_physical_assets_test`, `g5_industrial_asset_fallback_test`, `tp_student_visual_resume_test`, audit catalogue #140 |
| Alarmes, coupure audio et animation des récepteurs | `industrial_alarm_audio.dart`, `rotor_motion.dart` et hooks dans le workspace actuel | `industrial_audio_motion_test` |
| Schéma multifilaire, références croisées, SVG/PDF | Génération `electrosim_schematic`, `industrial_schematic_references.dart`, `industrial_schematic_svg_export.dart` et export PDF | `postv2_p3_*`, `industrial_schematic_projection_test` |
| Repérage industriel P4 et édition réservée au professeur | Registre persistant et actions du workspace actuel | `postv2_p4_marking_registry_test`, `postv2_p4_marking_workspace_test` |
| Une seule classe active, retour Home et gestion/reprise | `f18_session_coordinator.dart`, `f18_home.dart`, serveur LAN | `g5_teacher_tp_publication_navigation_test`, `f17_lan_sync_test` |
| QR réutilisable, identité élève, géométrie et avancée conservées | `electrosim_student_web_sync.dart`, callback de layout et `RotatedBox` | `tp_student_visual_resume_test`, `tp_real_browser_journey_test` |
| Soumission en lecture seule, notation et fermeture professeur | Contrôleur TP et synchronisation LAN/Web | `f17_tp_session_*`, `f18_point4_teacher_tp_supervision_test`, parcours Chromium |
| Client élève local dans le paquet Mac | CanvasKit local, Roboto, MIME Wasm et workflows G5/F17 | `f17_student_web_bundle_test`, `f17_lan_sync_test`, parcours HTTPS bloqué, validation d'archive Mac |

La suite initiale de cette G5 passe **744 tests applicatifs, 2 ignorés**, et
**107 tests Canvas**. Après restauration, les références F9 changent uniquement
pour le matériau du fond ; les dix captures ont été inspectées avant leur mise
à jour. Les fichiers de composants/assets industriels ne sont pas modifiés.
Après correction : **749 tests applicatifs, 2 ignorés**, **114 tests Canvas**,
analyse sans anomalie et deux parcours TP Chromium réussis.
Les résultats finaux et les SHA effectivement distribués sont ceux des workflows
GitHub liés à la PR de restauration ; les preuves produites enregistrent leur
`SOURCE_SHA.txt` et leurs empreintes.

## État des autres travaux et limites

### Candidat QR fourni par l'utilisateur

L'archive utilisateur SHA256
`288d7586623a20ee16720533d7e670779aae992945026cdb4787339ad1c12044`
est l'artefact `11747234988`, run `38249490948`, source
`7f8ad9c976f98ba73add32f9903269653d569dd7`.
Son ZIP natif `ElectroSim_PR98_Requalified_Mac_Intel.zip` porte l'empreinte
`763a2839f64f274c9ac81f31cdf72a439f22fe0c7a348becc4267e077be59579`.
Le validateur d'archive reproduit `F17_WEB_BUNDLE_MISSING: index.html` :
ce candidat PR98 compilait seulement l'application Mac, sans client élève,
contrairement aux candidats G5 Industrial et F17.

Le workflow PR98 compile maintenant le véritable client élève depuis le même
SHA, avec moteur et polices locales, l'embarque dans les ressources de l'app,
valide l'app et le ZIP final et refait/vérifie la signature après ajout des
ressources. Une CI native verte seule n'est plus présentée comme preuve du QR.

Le parcours Chromium a également exposé un défaut du script de qualification :
après un glissement, il supprimait les styles `pointer-events` des couches
d'accessibilité, créant un conteneur qui interceptait Rotation. Il conserve
et restaure désormais les styles d'origine ; les deux parcours complets passent
localement après correction, sans cliquer de force ni supprimer d'assertion.

Les passifs, diodes/LED, sources/PV, instruments et lots électriques récents sont
maintenant inclus via les intégrations de G5, dont #140. L'inventaire actuel
`docs/g5-proofs/catalogue-audit-20261012/catalogue.json` couvre 82 entrées :
81 rendus de maillages et un dessin Dart en perspective. Ce n'est pas une scène
3D temps réel de tous les appareils.

Les PR pneumatiques #124/#133/#136/#137/#138/#139 sont encore en brouillon au
moment de l'audit, certaines demandant explicitement de ne pas fusionner dans
G5. Elles ne sont pas des travaux perdus à restaurer. Les anciens brouillons
de voltmètre et de contrats restent distincts du contenu réellement livré par
les intégrations récentes. Les PR historiques vers `main` ne remplacent pas G5.

Les suites testent les scénarios modélisés, pas toutes les exigences physiques
de tous les appareils. QR décodé par programme ; serveur natif et vrai Chromium,
avec connexion loopback au même port. Reprise dans le même stockage navigateur,
avec le même nom, tant que le serveur professeur reste actif. Pas de validation
physique Mac, caméra téléphone ou réseau Wi-Fi réel.

## Prévention

La qualification G5 exécute toute la suite applicative et toute la suite Canvas,
incluant désormais les tests raster du matériau. Ainsi, réintroduire un peintre
sans métal ne peut plus passer simplement parce que les anciens commits sont
dans l'historique. Après chaque réconciliation, vérifier le contenu et les tests
du SHA final, puis la provenance des captures et du paquet distribué au SHA
fusionné ; ne pas assimiler CI historique verte et contenu actuel.

Le workflow exige aussi explicitement la présence des dix fichiers de
régression livrés (métal, armoire, représentations, goulottes, PDF, repérage et
TP). Une fusion qui supprime l'un de ces tests échoue avant de lancer les suites,
au lieu de réduire silencieusement la couverture et de rester verte.

Les dix références Mac F9 ont également été inspectées sur le rendu CI exact
`0547ff31350c678e7b41a062a02bfd6fb553a566`, dont l'arbre correspond au commit
de restauration `743cbb09`. Les cinq autres captures Mac et leurs masters Linux
restent byte-identiques aux références précédentes. Le validateur existant
accepte les quinze empreintes après mise à jour de la liste approuvée ; aucune
tolérance supplémentaire ni échec fonctionnel n'est masqué.
