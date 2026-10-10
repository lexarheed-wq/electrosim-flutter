# Audit G5 — platine industrielle et vue schéma

Date : 9 octobre 2026. Sources examinées : commit `3c9f3395e679c9739d00ce1c2afd20113fc70ac0`, après fusion de la PR 60. Audit statique du code, des tests et des workflows ; aucune manipulation physique de l'application Mac ni validation visuelle des captures effectuée pendant cet audit.

## Objectif exprimé

Deux commandes Platine / Schéma pour le même circuit. Platine : composants industriels réalistes, vue de face avec relief pour câbler et aperçu 3D complémentaire (choix confirmé par l'utilisateur). Schéma : symboles et câblage sur fond blanc, sans les enveloppes réalistes. Inclure rails DIN, goulottes et armoires électriques. Hypothèse proposée : la première vue Schéma conserve l'implantation de la platine ; un schéma fonctionnel réorganisé est une évolution distincte.

## État constaté

| Domaine | G5 actuel | Écart à l'objectif |
|---|---|---|
| Composants physiques | Images issues de modèles Cycles, vues front/palette, états de commande pilotés par le runtime, secours natifs | Rendu partiel du catalogue ; pas de scène 3D orientable |
| Double vue | `F18IndustrialPresentation.palettePerspective / boardFront` | Ce sont les présentations palette/platine, pas Platine/Schéma |
| Atelier | Panneaux latéraux réglables, responsive, préférences mémorisées | Ajouter une commande Platine/Schéma explicite |
| Implantation | Une `CircuitVisualLayout` : positions, dimensions, rotations, routes, fixtures | Pas de géométrie spécifique aux symboles ni de disposition Schéma indépendante |
| Rails | Rails explicites P2 et rails décoratifs historiques, assistance DIN au relâchement | Ancre de montage et dimensions physiques à formaliser ; pas de relation persistante appareil/rail |
| Goulottes | Rectangles à fentes, déplacement/redimensionnement, routage orthogonal | Planificateur limité à une goulotte par connexion ; pas de réseau de goulottes ni de couvercles |
| Borniers | Zone géométrique ; composant électrique `terminal_block_5` existant | Zone et bornes réelles ne sont pas structurées en assemblage industriel |
| Armoire | `CabinetLayout` contient seulement des fixtures | Pas de modèle de coffret, plaque de fond, profondeur, porte ou surface externe |
| Sauvegarde | Schéma de géométrie v2, lecture v1 conservée | Ajouter les représentations sans perdre les anciens placements |

## Constats techniques prioritaires

1. `apps/electrosim/lib/f18_industrial_dual_view.dart` et ses tests imposent une platine frontale sans transformation. Le nom dual-view ne prouve donc pas l'existence de la fonction demandée.
2. `packages/electrosim_canvas/lib/src/circuit_scene_painter.dart` utilise un fond gris clair quadrillé fixe. Le booléen `paintElementChrome` pilote les couches de rendu ; il ne constitue pas un mode Schéma. Les instruments sont encore peints physiquement indépendamment de ce booléen.
3. `packages/electrosim_canvas/lib/src/cabinet_layout.dart` définit seulement `dinRail`, `wireDuct`, `terminalZone`. Les dimensions sont en unités monde ; le placement DIN aligne le centre graphique de l'appareil sur celui du rail. Une attache mécanique distincte du centre est nécessaire. Le planificateur possède une fonction de limitation à un rectangle, mais l'armoire n'a pas de limites persistées dans ce modèle.
4. `packages/electrosim_canvas/lib/src/cabinet_duct_wire_planner.dart` compare des routes passant par chaque goulotte individuellement et retient la plus courte. Il ne calcule pas une route passant par plusieurs goulottes raccordées.
5. `_routeWiresViaCabinetDucts` dans `main.dart` annonce un refus de traversée d'un composant. Or `F18WorkspaceWireSafety.isRenderable` vérifie les bornes et la validité d'un `OrthogonalWirePath`, sans comparaison du chemin avec les rectangles des appareils. Le contrôle et son message ne correspondent pas. C'est un défaut de contrat constaté par lecture, pas une reproduction dans l'application.
6. Les tests P2 UI vérifient création, Undo/Redo, déplacement, redimensionnement, suppression et activation du mode DIN. Le test de routage UI fonctionne sans source ni charge : il ne prouve pas le trajet d'un circuit équipé. Il manque un scénario complet composant → rail → câblage multi-goulottes → sauvegarde/réouverture.
7. Les rendus physiques sont partagés et décodés à l'avance, avec états ON/OFF/TRIP séparés et secours natifs : cette base doit être conservée. Ils ne sont pas un moteur 3D interactif.
8. Le catalogue comparatif recense 74 entrées mais documente des familles encore schématiques. Les tailles actuelles assurent une cohérence visuelle partielle, pas une conversion mm/unité garantie pour tous les appareils.
9. Le workflow G5 exécute les suites application et Canvas. Il ne lance pas directement toutes les suites de packages solveurs AC/DC/PV. Le workflow P2 les lance sur P2, mais uniquement sur cette branche : élargir le contrôle commun G5 pour les futurs changements d'implantation.
10. Le workflow visuel régénère certaines références et peut pousser un commit de preuve `[skip ci]`. Distinguer captures produites pour examen et références visuelles approuvées ; ne pas assimiler une régénération à une acceptation humaine.

## Architecture recommandée

Conserver un circuit électrique unique et le même résultat de simulation. Les identifiants de composants, de bornes et de connexions sont communs aux deux vues. Les coordonnées visuelles ne définissent jamais les connexions électriques.

Créer un mode de présentation explicite Platine / Schéma, des géométries d'ancres propres à chaque rendu et une correspondance par identifiant de borne. Le passage d'une vue à l'autre ne doit ni déplacer les appareils physiques ni changer les courants ni modifier une connexion. Les extrémités graphiques des fils sont reprojetées vers les ancres appropriées.

Pour la première version, garder l'ordre spatial de la platine en mode Schéma, dessiner des symboles noirs sur fond blanc et rerouter leurs connexions sans convertir chaque courbe physique en trait de schéma. Masquer textures, ombres, enveloppes, rails et goulottes ; conserver éventuellement un contour de platine désactivable. Prévoir zoom et cadrage propres à chaque vue. La sélection et l'inspecteur identifient le même appareil dans les deux vues.

Pour le contacteur, distinguer appareil physique et représentations schématiques : un contacteur peut avoir une bobine et plusieurs contacts dessinés séparément, tous liés au même équipement par le repère KM1 et les ports réels. Ne pas les transformer en appareils indépendants lors du changement de vue. Prévoir d'abord un symbole groupé, puis une représentation développée pour commande et puissance.

Structurer un modèle physique en millimètres : enveloppe, profondeur, type de montage, ancre DIN, empreinte, positions des bornes, dégagements. Les tailles de palette restent indépendantes des tailles de platine. Un rail reçoit une relation de montage explicite ; déplacer le rail ne déplace pas silencieusement ses équipements.

Ajouter un modèle d'armoire : largeur/hauteur/profondeur, plaque de fond, limites utilisables et surfaces de montage. Distinguer intérieur sur rails, porte avec boutons/voyants, et équipements extérieurs (moteur, pompe). Une pompe ou un moteur industriel ne doit pas être monté artificiellement sur un rail DIN.

Modéliser un réseau de goulottes reliées avec entrées/sorties et segments horizontaux/verticaux. Calculer les chemins dans ce réseau et contrôler les obstacles. En platine, afficher une courte sortie de borne puis le faisceau dans la goulotte ; proposer couvercles ouverts/fermés. Les rayons de courbure, sections et capacité de remplissage exigent des données supplémentaires et doivent rester hors du premier incrément si elles ne sont pas disponibles.

Créer des rangées de bornes individuelles avec repérage, pontages et bornes PE réels, liées au modèle électrique. Une zone géométrique de borniers ne peut pas remplacer ces connexions.

## Trois approches

1. Remplacer les textures par des symboles au même emplacement : rapide, utile pour une première étape, mais limitée pour les contacts distribués et les réseaux denses.
2. Circuit unique et représentations structurées par vue : recommandée. Permet une première projection conservant l'implantation puis une disposition schématique fonctionnelle sans réécrire le circuit.
3. Construire immédiatement un éditeur 3D complet et un outil de CAO schématique : coût et complexité élevés ; à différer tant que les contrats des deux vues ne sont pas établis.

## Ordre proposé

1. Consolider G5 : corriger le contrôle d'obstacles, tester une platine câblée complète, mettre à jour la documentation P2 et qualifier le résultat fusionné.
2. Livrer Platine / Schéma sur un circuit industriel représentatif : source, protection, contacteur, thermique, moteur, boutons, voyant et borniers. Symboles et ancres corrects, fond blanc, sélection commune, sauvegarde des vues.
3. Construire l'armoire physique : dimensions mm, plaque, rails, montage, goulottes raccordées et borniers réels.
4. Étendre la couverture du catalogue et ajouter l'aperçu 3D de l'armoire construite, sans un deuxième circuit électrique.
5. Ajouter éventuellement schéma développé commande/puissance, folios, renvois et export vectoriel.

## Critères d'acceptation

- Un montage Marche/Arrêt à auto-maintien pilote exactement le même moteur dans les deux vues.
- Tous les ports visibles correspondent à des bornes réelles ; une connexion conserve son identité entre vues.
- Changer de vue conserve le circuit, l'état de simulation et l'implantation physique.
- Aucun composant réaliste, instrument physique ou goulotte ne subsiste dans le schéma lorsque cette couche est masquée.
- Une route passe par au moins deux goulottes raccordées, évite un appareil et distingue croisement de jonction.
- Une armoire équipée et câblée retrouve placements et connexions après réouverture ; Undo/Redo fonctionne.
- Tailles, ancre DIN, limites de plaque et montage sur porte sont vérifiés sur des équipements de référence.
- Qualification automatisée, revue des captures et essai Mac avec trackpad sont documentés séparément.

## Qualification après fusion

Run suivi : https://github.com/lexarheed-wq/electrosim-flutter/actions/runs/37991923591

Dernière vérification : runtime-regression réussi ; visual-evidence réussi ; macos-intel en cours. L'artefact `G5-Industrial-Flutter-real-proof` (11645253808) est disponible et associé au SHA exact `3c9f3395e679c9739d00ce1c2afd20113fc70ac0`. Aucun artefact Mac encore disponible. Surveillance horaire créée avec autorisation de diagnostiquer et corriger les erreurs de qualification, sans implémenter automatiquement les propositions de cet audit.
