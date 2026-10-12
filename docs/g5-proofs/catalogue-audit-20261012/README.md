# Audit complet du catalogue G5 — 12 octobre 2026

82 entrées de palette contrôlées après décodage des assets et peinture réelle des vues palette et platine. 81 utilisent des images issues de maillages Blender Cycles ; le différentiel utilise `Disjoncteur3D`, un dessin Dart avec perspective et relief. Ce rendu n'est pas un objet 3D temps réel manipulable dans l'application. Aucun repli sur une icône d'identité générique ; les contrats des composants correspondent aux nombres de contacts déclarés dans la palette.

Les deux prises vectorielles ont été remplacées par des modèles originaux : prise AC générique de type E (broche PE) et connecteur CC à deux pôles détrompé. Leurs positions et tailles de contacts historiques restent inchangées. Les contacts d'entrée sont une projection de maintenance ; les contacts de fiche sont sans vis. Aucun calibre, norme de connecteur CC, certification ni constructeur n'est inventé.

- [Prise AC, perspective](power_socket_ac-palette.png) / [face](power_socket_ac-front.png)
- [Connecteur CC, perspective](power_socket_dc-palette.png) / [face](power_socket_dc-front.png)
- [Prise branchée et terre](connected-pe.png) / [fiche débranchée](unplugged.png)
- [Dernier lot : 42 captures Flutter](../lot-16-26/README.md)
- [Inventaire machine complet](catalogue.json)

## Vérifications électriques et limites

Les contrats vérifiés portent sur les identifiants, types, nombre de bornes et modes. Ils ne certifient pas un comportement identique à chaque appareil réel. Les essais électriques vérifient notamment les protections, terre, mesures, fusibles, couplages moteur et compteurs dans les scénarios du dépôt. Les modèles restent pédagogiques : réfrigération sans thermodynamique complète, charges moteur AC sans glissement/inertie mécanique, sources idéales, relais/contacts idéalisés et PV autonome. Voir [les limites détaillées](../lot-16-26/references-and-limits.md). Les convertisseurs d'un atelier mixte et le secours PV/batterie/réseau ne sont pas ajoutés ici.

Un défaut historique réel a été corrigé : sur une batterie autonome en mode PV, l'ampèremètre n'était pas projeté avec son shunt avant conversion en CC. Les lectures utilisent maintenant la topologie effectivement calculée, tout en validant le câblage sur le projet auteur. Le courant mesuré est 0,9981285 A avec la résistance interne et la charge du test. La copie de calcul ne remplace pas le circuit sauvegardé.

41 tests ciblés de mesures, compteurs, fusibles, terre et coordonnées des prises passent. 4 contrôles supplémentaires passent pour le catalogue, les vues et le branchement de la prise. Le dernier lot a passé 18 tests de captures et de rotation/audio ; les suites Dart domaine et PV ont passé respectivement 41 et 43 tests. L'analyse statique des nouveaux outils et des fichiers de correction ne signale pas d'anomalie.

## Résultat local sur la G5 consolidée

Suite complète : **744 succès, 2 ignorés, aucun échec**. Les 16 échecs historiques ont été traités : correction réelle du shunt PV, stabilisation de la liste rapide CC indépendante du décodage des images, correction du débordement des menus de raccordement, préconditions de recherche/défilement dans les tests UI, bornage correct du contrôle de routage et adaptation explicite des attentes de variantes/tailles natives.

Les dix références F9 ont été actualisées après inspection des images originales et nouvelles (barre de commandes, palette et volet propriétés) ; les autres références sont conservées. Ce sont des fixtures structurelles Flutter avec sa police de test, distinctes des 42 preuves lisibles avec les vraies polices. Les anciennes différences ne sont pas transformées en tolérance arbitraire. Le contrôle Mac Intel exige de nouvelles captures et une inspection de leurs empreintes avant validation de son manifeste.

Analyse complète après nettoyage des imports, accolades et traces d'outils : **aucune anomalie**. Les 14 tests ciblés des contrôles de voltmètre, de l'ohmmètre et des contacts physiques passent après ce nettoyage sans changement de loi électrique. Les gardes `CORE_UNIFY_ARCHITECTURE_GUARD` et `POSTV2_P1_CONTRACT` passent.

Revue indépendante ciblée runtime/ports/persistance : aucun Critical/Important confirmé. Limite supplémentaire des compteurs : la commande de réinitialisation de simulation recharge les index sauvegardés et annule les incréments non enregistrés ; ce n'est pas le comportement irréversible d'un compteur matériel.

## Périmètre pneumatique préservé

La G5 récente contient un atelier **expérimental**, séparé du catalogue électrique. Ses dix familles (`idealSource`, `valve32`, `valve52`, `singleActingCylinder`, `doubleActingCylinder`, `restrictor`, `checkValve`, `tee`, `manometer`, `silencer`) utilisent actuellement `PneumaticDeviceGlyph`, un dessin vectoriel. Elles ne sont **pas** converties en équipements 3D réalistes par cette fusion électrique. Leurs fichiers et les calculs R6 récents restent conservés.

L'affirmation « tous les équipements de G5 sont en 3D » serait donc fausse si elle inclut la pneumatique. Pour l'électricité : 81 rendus de maillages et un dessin Dart 3D en perspective, pas une scène 3D temps réel. Pour la conformité scientifique complète : les réserves des modèles pédagogiques restent ouvertes. Les essais Mac/Chromium, la compilation distribuable et les performances à 400 composants nécessitent leurs campagnes propres.

## Inventaire

| Appareil | Clé stable | Procédé visuel | Contacts palette | Modes |
|---|---|---|---:|---|
| Connecteur alimentation CC | power_socket_dc | Cycles mesh | 4 | dc |
| Prise alimentation L/N/PE | power_socket_ac | Cycles mesh | 6 | ac1/ac3 |
| Voltmètre physique | instrument-voltmeter | Cycles mesh | 0 | dc/ac1/ac3/pv |
| Ampèremètre physique | instrument-ammeter | Cycles mesh | 0 | dc/ac1/ac3/pv |
| Fréquencemètre physique | instrument-frequency | Cycles mesh | 0 | ac1/ac3 |
| Contrôleur d’ordre des phases | instrument-phase-sequence | Cycles mesh | 0 | ac3 |
| Source CC 24 V | source-dc-24v | Cycles mesh | 2 | dc |
| Interrupteur NO | switch-no | Cycles mesh | 2 | dc/ac1/ac3 |
| Lampe | lamp | Cycles mesh | 2 | dc |
| Lampe 230 V AC | lamp-ac1-230v | Cycles mesh | 2 | ac1/ac3/pv |
| Résistance | resistor | Cycles mesh | 2 | dc/ac1/ac3/pv |
| Disjoncteur | breaker | Cycles mesh | 2 | dc |
| Lampe 48 V CC | lamp-dc-48v | Cycles mesh | 2 | dc/pv |
| Bouton-poussoir NO | push-button-no | Cycles mesh | 2 | dc/ac1/ac3 |
| Bouton-poussoir NC | push-button-nc | Cycles mesh | 2 | dc/ac1/ac3 |
| Buzzer | buzzer | Cycles mesh | 2 | dc |
| Fusible | fuse | Cycles mesh | 2 | dc |
| Diode redresseuse | diode | Cycles mesh | 2 | dc |
| Diode Schottky | diode-schottky | Cycles mesh | 2 | dc |
| LED rouge | led-red | Cycles mesh | 2 | dc |
| LED verte | led-green | Cycles mesh | 2 | dc |
| Diode Zener 5,1 V | zener-5v1 | Cycles mesh | 2 | dc |
| Diode TVS 12 V | tvs-12v | Cycles mesh | 2 | dc |
| Ventilateur CC | fan-dc | Cycles mesh | 2 | dc |
| Moteur CC | motor-dc | Cycles mesh | 2 | dc |
| Bobine relais 24 V CC | relay-coil | Cycles mesh | 2 | dc |
| Contact relais NO | relay-contact-no | Cycles mesh | 2 | dc |
| Contact relais NC | relay-contact-nc | Cycles mesh | 2 | dc |
| Broyeur industriel | external-crusher | Cycles mesh | 6 | ac3 |
| Climatiseur | external-air-conditioner | Cycles mesh | 2 | ac1 |
| Compresseur industriel | external-compressor | Cycles mesh | 6 | ac3 |
| Congélateur | external-freezer | Cycles mesh | 2 | ac1 |
| Convoyeur | external-conveyor | Cycles mesh | 6 | ac3 |
| Fer à repasser | external-iron | Cycles mesh | 2 | ac1 |
| Mélangeur industriel | external-mixer | Cycles mesh | 6 | ac3 |
| Ordinateur | external-computer | Cycles mesh | 2 | ac1 |
| Pompe industrielle | external-pump-3p | Cycles mesh | 6 | ac3 |
| Pompe monophasée | external-pump-ac1 | Cycles mesh | 2 | ac1 |
| Pompe solaire DC | external-solar-pump | Cycles mesh | 2 | dc |
| Réfrigérateur | external-refrigerator | Cycles mesh | 2 | ac1 |
| Réfrigérateur solaire DC | external-refrigerator-dc | Cycles mesh | 2 | dc |
| Télévision | external-tv | Cycles mesh | 2 | ac1 |
| Ventilateur domestique | external-fan-ac1 | Cycles mesh | 2 | ac1 |
| Ventilateur industriel | external-fan-3p | Cycles mesh | 6 | ac3 |
| Source de courant CC | source-dc-current | Cycles mesh | 2 | dc |
| Source AC 230 V | source-ac1-230v | Cycles mesh | 2 | ac1 |
| Source de courant AC | source-ac1-current | Cycles mesh | 2 | ac1 |
| Réseau triphasé — L1 | source-ac3-l1 | Cycles mesh | 2 | ac3 |
| Réseau triphasé — L2 | source-ac3-l2 | Cycles mesh | 2 | ac3 |
| Réseau triphasé — L3 | source-ac3-l3 | Cycles mesh | 2 | ac3 |
| Champ photovoltaïque | pv-array | Cycles mesh | 2 | pv |
| Champ photovoltaïque haute tension | pv-array-high-voltage | Cycles mesh | 2 | pv |
| Régulateur solaire MPPT | pv-controller-mppt | Cycles mesh | 4 | pv |
| Régulateur solaire PWM | pv-controller-pwm | Cycles mesh | 4 | pv |
| Batterie photovoltaïque | pv-battery | Cycles mesh | 2 | dc/pv |
| Onduleur solaire 1φ | pv-inverter | Cycles mesh | 4 | pv |
| Charge AC PV | pv-resistive-load | Cycles mesh | 2 | pv |
| Réseau triphasé 400/230 V | source-ac3-grid | Cycles mesh | 4 | ac3 |
| Alternateur triphasé | source-ac3-alternator | Cycles mesh | 4 | ac3 |
| Moteur triphasé 6 bornes | motor-3p-6t | Cycles mesh | 6 | ac3 |
| Charge triphasée Y (3 impédances) | load-wye-3p | Cycles mesh | 4 | ac3 |
| Charge triphasée Δ (3 impédances) | load-delta-3p | Cycles mesh | 3 | ac3 |
| Compteur énergie AC | energy-meter-ac1 | Cycles mesh | 4 | ac1 |
| Compteur énergie triphasé | energy-meter-ac3 | Cycles mesh | 8 | ac3 |
| Compteur énergie PV | energy-meter-pv | Cycles mesh | 4 | pv |
| Condensateur | capacitor | Cycles mesh | 2 | dc/ac1/ac3 |
| Inductance | inductor | Cycles mesh | 2 | dc/ac1/ac3 |
| Impédance | impedance | Cycles mesh | 2 | ac1/ac3 |
| Différentiel 2P AC | rcd-2p-ac1 | Dart perspective painter | 4 | ac1 |
| Disjoncteur AC 1φ | breaker-ac1 | Cycles mesh | 2 | ac1 |
| Fusible AC 1φ | fuse-ac1 | Cycles mesh | 2 | ac1 |
| Contact auxiliaire NO | aux-contact-no | Cycles mesh | 2 | ac1/ac3 |
| Contact auxiliaire NC | aux-contact-nc | Cycles mesh | 2 | ac1/ac3 |
| Contacteur AC 1φ | contactor-ac1 | Cycles mesh | 4 | ac1 |
| Contacteur 3P | contactor-3p | Cycles mesh | 8 | ac3 |
| Disjoncteur 3P | breaker-3p | Cycles mesh | 6 | ac3 |
| Sectionneur 3P | isolator-3p | Cycles mesh | 6 | ac3 |
| Sectionneur 4P | isolator-4p | Cycles mesh | 8 | ac3 |
| Disjoncteur 4P | breaker-4p | Cycles mesh | 8 | ac3 |
| Bornier CC +/−/PE | terminal-block-dc-5 | Cycles mesh | 10 | dc |
| Bornier L1/L2/L3/N/PE | terminal-block-5 | Cycles mesh | 10 | ac3 |
| Relais thermique 3P | thermal-overload-3p | Cycles mesh | 6 | ac3 |

## Consolidation des contrôles GitHub

41 tests ciblés de raccordement, terre, défaut d’isolement et coupure série ajoutés au package domaine : 82 tests réussis, couverture 1085/1183 lignes (91,72 %, seuil 90 %). Fixtures DC corrigées à quatre ports et mode DC. Format Dart vérifié ; analyse du domaine sans diagnostic. Les journaux de preuve sont normalisés uniquement pour supprimer les espaces terminaux et retours de progression console incompatibles avec `git diff --check` ; les résultats sont conservés.

Revue des 15 captures Mac et manifeste exact mis à jour après inspection indépendante : [preuves Mac](mac-review/README.md). Les contrôles GitHub doivent encore être rejoués sur la nouvelle tête avant fusion.
