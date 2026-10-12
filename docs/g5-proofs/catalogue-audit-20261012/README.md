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

## Suite globale

Avant correction du défaut PV, la suite complète donnait 720 succès, 16 échecs historiques et 2 tests ignorés. Ces 16 échecs ont été reproduits sur le commit publié précédent ; un des 16 concerne le défaut PV corrigé ici. Les autres concernent des attentes historiques de palette, des références graphiques et un contrôle textuel de routage. Ils ne sont pas masqués ni supprimés. Le résultat final sur la branche d'intégration doit être enregistré après fusion locale avant publication.

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
