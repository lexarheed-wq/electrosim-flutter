# F9 — Spécification détaillée des familles de composants

**Préparation uniquement. F9 reste fermée tant que `F8_GATE_PASS` n’est pas confirmé.**

Ce document définit la cible graphique et interactive. Il ne crée aucun composant de production et ne réimporte aucun composant historique. L’inventaire legacy sert uniquement à vérifier que les familles d’usage ont été prises en compte.

## 1. Règles communes

- Une identité visuelle canonique est partagée entre palette et Canvas ; la palette peut simplifier, jamais changer de métaphore.
- La géométrie visuelle ne détermine aucune grandeur électrique. Les états électriques affichés proviennent uniquement des résultats des moteurs métier.
- Les états UI (`hover`, `selected`, `focused`, `dragging`, câblage) restent séparés des états physiques (`energized`, `running`, `tripped`, etc.).
- Une borne conserve la même position relative au composant quel que soit le breakpoint ; seul son hit-target écran peut être agrandi.
- Les phases, polarités et rôles sont lisibles par texte/symbole et jamais uniquement par couleur.
- Les animations ne deviennent jamais une source de vérité. Elles représentent un état déjà calculé.

## 2. Gabarits visuels proposés

| Token | Empreinte monde de référence | Usage |
|---|---:|---|
| XS | 64 × 40 | symbole très simple, 2 bornes |
| S | 80 × 48 | passif, diode, petit contact |
| M | 104 × 64 | gabarit F8 existant, source simple, protection, mesure |
| L | 136 × 80 | triphasé, PV, stockage |
| XL | 168 × 104 | conversion, appareil externe complexe |

Ces dimensions sont des **tokens de préparation visuelle**, pas des contraintes électriques. Le Canvas F8 utilise déjà 104 × 64 comme taille par défaut ; F9 pourra spécialiser les familles sans modifier `CircuitState`.

## 3. Détail par famille

### 1. `sources-dc` — Sources CC

- **Domaine :** DC. **Statut :** active. **Références legacy couvertes :** 8 (référence uniquement, import automatique = NON).

- **Silhouette :** Bloc source rectangulaire, repère +/− visible, variantes alimentation/batterie sans changer la grammaire.
- **Gabarit :** `M`. **Bornes :** `dc_pos;dc_neg`. **Marquages persistants :** +;−;Vdc.

- **États affichables :** deenergized;energized;limited;disabled. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** none.
- **Compact :** Silhouette + polarités; valeur secondaire masquée si nécessaire.
- **Medium :** Silhouette + polarités + valeur nominale courte.
- **Expanded :** Marquages complets, valeur nominale, état source.
- **Priorité future :** `P1`.

### 2. `sources-ac1` — Sources AC monophasées

- **Domaine :** AC1. **Statut :** active. **Références legacy couvertes :** 2 (référence uniquement, import automatique = NON).

- **Silhouette :** Bloc source avec glyph 1~ / sinusoïde, bornes L et N clairement séparées.
- **Gabarit :** `M`. **Bornes :** `ac_l;ac_n;pe_optional`. **Marquages persistants :** 1~;L;N;Hz.

- **États affichables :** deenergized;energized;undervoltage;overvoltage;disabled. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** none.
- **Compact :** 1~ + L/N; fréquence cachée hors sélection.
- **Medium :** 1~ + L/N + tension courte.
- **Expanded :** Tension, fréquence et état source lisibles.
- **Priorité future :** `P1`.

### 3. `sources-ac3` — Sources triphasées

- **Domaine :** AC3. **Statut :** active. **Références legacy couvertes :** 3 (référence uniquement, import automatique = NON).

- **Silhouette :** Bloc 3~ avec rangée de bornes ordonnée L1 L2 L3 N, PE distinct si présent.
- **Gabarit :** `L`. **Bornes :** `l1;l2;l3;n_optional;pe_optional`. **Marquages persistants :** 3~;L1;L2;L3;N.

- **États affichables :** deenergized;energized;phase_loss;phase_swap;undervoltage;overvoltage;disabled. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** none.
- **Compact :** 3~ + L1/L2/L3; N/PE visibles si présents.
- **Medium :** Repères phases + tension composée courte.
- **Expanded :** Repères complets, fréquence, état de phase.
- **Priorité future :** `P1`.

### 4. `passive-resistive-sensors` — Résistifs et capteurs passifs

- **Domaine :** DC/AC1. **Statut :** active. **Références legacy couvertes :** 9 (référence uniquement, import automatique = NON).

- **Silhouette :** Corps linéaire à deux bornes; pictogramme interne différencie résistance, thermistance, photo-résistance, capteur passif.
- **Gabarit :** `S`. **Bornes :** `two_terminal_bidirectional`. **Marquages persistants :** symbole métier;valeur si utile.

- **États affichables :** normal;energized;overrange. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** none.
- **Compact :** Symbole métier seul + bornes.
- **Medium :** Symbole + valeur courte.
- **Expanded :** Valeur/unité et état dérivé affichables.
- **Priorité future :** `P2`.

### 5. `passive-rlc` — Capacitifs et inductifs

- **Domaine :** DC/AC1. **Statut :** active. **Références legacy couvertes :** 8 (référence uniquement, import automatique = NON).

- **Silhouette :** Deux bornes avec symbole C/L canonique; polarité explicitée pour variantes polarisées.
- **Gabarit :** `S`. **Bornes :** `two_terminal_or_polarized`. **Marquages persistants :** C/L;+ si polarisé;valeur.

- **États affichables :** normal;energized;charged;saturated_or_overrange. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** none.
- **Compact :** Symbole C/L, polarité si nécessaire.
- **Medium :** Symbole + valeur courte.
- **Expanded :** Valeur, polarité, état pertinent.
- **Priorité future :** `P2`.

### 6. `dc-semiconductors` — Semi-conducteurs CC

- **Domaine :** DC. **Statut :** active. **Références legacy couvertes :** 8 (référence uniquement, import automatique = NON).

- **Silhouette :** Symbole directionnel dans un boîtier léger; anode/cathode ou autres repères explicités.
- **Gabarit :** `S`. **Bornes :** `semiconductor_variant`. **Marquages persistants :** A;K;G selon variante.

- **États affichables :** off;conducting;blocked;reverse;overrange. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** LED only from result.
- **Compact :** Symbole + A/K ou labels requis.
- **Medium :** Symbole + labels + état discret.
- **Expanded :** Marquages complets; luminance LED si calculée.
- **Priorité future :** `P2`.

### 7. `protection-generic` — Protection CC / AC

- **Domaine :** DC/AC1. **Statut :** active. **Références legacy couvertes :** 7 (référence uniquement, import automatique = NON).

- **Silhouette :** Boîtier de protection avec chemin entrée→sortie lisible; levier/fusible selon variante.
- **Gabarit :** `M`. **Bornes :** `line_load_pair_or_poles`. **Marquages persistants :** IN/OUT;calibre si validé.

- **États affichables :** closed;open;tripped;blown;deenergized. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** mechanical state transition only.
- **Compact :** État mécanique et bornes visibles.
- **Medium :** État + calibre court si disponible.
- **Expanded :** Marquages entrée/sortie et cause de déclenchement si prouvée.
- **Priorité future :** `P1`.

### 8. `control-detection` — Commande et détection

- **Domaine :** DC/AC1. **Statut :** active. **Références legacy couvertes :** 29 (référence uniquement, import automatique = NON).

- **Silhouette :** Boîtier compact avec actionneur/symbole NO/NC/capteur; contacts et bobines distincts.
- **Gabarit :** `M`. **Bornes :** `control_contact_or_coil`. **Marquages persistants :** NO/NC;A1/A2;13/14;21/22 selon type.

- **États affichables :** rest;actuated;open;closed;energized;disabled. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** actuator motion only from state.
- **Compact :** Symbole NO/NC ou actionneur + bornes principales.
- **Medium :** Repères normalisés visibles.
- **Expanded :** Repères complets et état mécanique/commande.
- **Priorité future :** `P1`.

### 9. `ac3-protection-distribution` — Distribution et protection 3φ

- **Domaine :** AC3. **Statut :** active. **Références legacy couvertes :** 11 (référence uniquement, import automatique = NON).

- **Silhouette :** Boîtier multipolaire large, colonnes de phases alignées verticalement entrée/sortie.
- **Gabarit :** `L`. **Bornes :** `l1_l2_l3_n_line_load`. **Marquages persistants :** L1/L2/L3/N;T1/T2/T3.

- **États affichables :** closed;open;tripped;phase_loss;deenergized. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** mechanical state transition only.
- **Compact :** 3 pôles + phase labels essentiels.
- **Medium :** Entrée/sortie et état mécanique.
- **Expanded :** Repères complets, calibre/état si disponible.
- **Priorité future :** `P1`.

### 10. `ac3-motor-control` — Commande moteur 3φ

- **Domaine :** AC3. **Statut :** active. **Références legacy couvertes :** 10 (référence uniquement, import automatique = NON).

- **Silhouette :** Contacteur/relais thermique/démarreur sous forme de bloc fonctionnel, puissance séparée de commande.
- **Gabarit :** `L`. **Bornes :** `three_phase_power_plus_control`. **Marquages persistants :** 1L1/3L2/5L3;2T1/4T2/6T3;A1/A2.

- **États affichables :** rest;coil_energized;contacts_closed;tripped;disabled. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** contact motion only from result.
- **Compact :** Puissance + A1/A2, détails secondaires repliés.
- **Medium :** Repères puissance/commande visibles.
- **Expanded :** Tous repères et état thermique/commande disponibles.
- **Priorité future :** `P1`.

### 11. `receivers-actuators` — Récepteurs et actionneurs CC / AC

- **Domaine :** DC/AC1. **Statut :** active. **Références legacy couvertes :** 29 (référence uniquement, import automatique = NON).

- **Silhouette :** Silhouette fonctionnelle identifiable (lampe, buzzer, chauffage, solénoïde, petit moteur) avec bornes latérales.
- **Gabarit :** `M`. **Bornes :** `load_variant`. **Marquages persistants :** type charge;polarité si requise.

- **États affichables :** off;energized;active;running;heating;overrange. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** only functional animation from SimulationResult.
- **Compact :** Silhouette métier + bornes.
- **Medium :** Silhouette + état discret.
- **Expanded :** Valeurs et animation fonctionnelle si pertinente.
- **Priorité future :** `P1`.

### 12. `ac3-loads` — Moteurs et charges 3φ

- **Domaine :** AC3. **Statut :** active. **Références legacy couvertes :** 7 (référence uniquement, import automatique = NON).

- **Silhouette :** Corps machine/charge industrielle avec 3~ ou symbole moteur; bornier U/V/W ou L1/L2/L3.
- **Gabarit :** `L`. **Bornes :** `u_v_w_or_three_phase_load`. **Marquages persistants :** 3~;U/V/W ou L1/L2/L3.

- **États affichables :** stopped;energized;running;phase_loss;phase_swap;overload. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** rotation/motion only from DeviceStateEngine result.
- **Compact :** Silhouette + 3~ + bornes.
- **Medium :** Bornes + état marche/arrêt.
- **Expanded :** Repères complets; animation et état mécanique.
- **Priorité future :** `P1`.

### 13. `sockets` — Prises

- **Domaine :** AC1/AC3. **Statut :** active. **Références legacy couvertes :** 4 (référence uniquement, import automatique = NON).

- **Silhouette :** Façade de prise simplifiée mais réaliste, bornes arrière/latérales explicites L/N/PE ou phases.
- **Gabarit :** `M`. **Bornes :** `socket_variant`. **Marquages persistants :** L;N;PE ou L1/L2/L3/N/PE.

- **États affichables :** deenergized;energized;connected_load_present. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** none.
- **Compact :** Face + labels de bornes indispensables.
- **Medium :** Face + bornes + type de prise.
- **Expanded :** Marquages complets et état alimentation discret.
- **Priorité future :** `P1`.

### 14. `external-appliances` — Appareils externes

- **Domaine :** DC/AC1/AC3. **Statut :** active. **Références legacy couvertes :** 18 (référence uniquement, import automatique = NON).

- **Silhouette :** Pictogramme industriel réaliste et homogène par appareil, avec connecteur électrique séparé du dessin mécanique.
- **Gabarit :** `XL`. **Bornes :** `appliance_variant`. **Marquages persistants :** nom court;mode électrique.

- **États affichables :** off;energized;running;active;disabled. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** only when physically meaningful and result-driven.
- **Compact :** Pictogramme simplifié + connecteur.
- **Medium :** Pictogramme + nom court + état.
- **Expanded :** Détails mécaniques fonctionnels, jamais décoratifs au détriment des bornes.
- **Priorité future :** `P2`.

### 15. `measurement` — Mesure

- **Domaine :** DC/AC1/AC3. **Statut :** active. **Références legacy couvertes :** 8 (référence uniquement, import automatique = NON).

- **Silhouette :** Instrument à écran/cadran, bornes dédiées clairement codées par texte et symbole.
- **Gabarit :** `M`. **Bornes :** `measurement_variant`. **Marquages persistants :** V/A/Ω/W selon instrument;COM;+.

- **États affichables :** idle;measuring;overrange;invalid_connection;unavailable. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** numeric/display update only from MeasurementEngine.
- **Compact :** Type instrument + lecture principale.
- **Medium :** Lecture + unité + bornes.
- **Expanded :** Lecture, unité, plage et état de validité.
- **Priorité future :** `P1`.

### 16. `pv-environment` — Environnement PV

- **Domaine :** PV. **Statut :** active. **Références legacy couvertes :** 3 (référence uniquement, import automatique = NON).

- **Silhouette :** Carte environnement distincte d’un composant câblable, avec soleil/température/irradiance.
- **Gabarit :** `M`. **Bornes :** `none_or_parameter_port`. **Marquages persistants :** G;T;profil.

- **États affichables :** normal;low_irradiance;high_temperature;unavailable. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** ambient indicator only.
- **Compact :** Icône soleil + valeur principale.
- **Medium :** Irradiance + température.
- **Expanded :** Paramètres environnement complets; aucun faux terminal électrique.
- **Priorité future :** `P2`.

### 17. `pv-generation` — Production photovoltaïque

- **Domaine :** PV. **Statut :** active. **Références legacy couvertes :** 7 (référence uniquement, import automatique = NON).

- **Silhouette :** Module/panneau PV à cellules stylisées, bornes PV+ et PV− sur un même bord fonctionnel.
- **Gabarit :** `L`. **Bornes :** `pv_pos;pv_neg`. **Marquages persistants :** PV;+;−;Pnom si disponible.

- **États affichables :** dark;generating;limited;reverse;disabled. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** irradiance highlight only from result.
- **Compact :** Panneau + PV+/PV−.
- **Medium :** Panneau + puissance courte.
- **Expanded :** Marquages électriques et état de production.
- **Priorité future :** `P1`.

### 18. `pv-protection` — Protection et sectionnement PV

- **Domaine :** PV. **Statut :** active. **Références legacy couvertes :** 4 (référence uniquement, import automatique = NON).

- **Silhouette :** Boîtier DC PV avec polarités doublées si nécessaire et chemin entrée/sortie explicite.
- **Gabarit :** `M`. **Bornes :** `pv_line_load_pairs`. **Marquages persistants :** PV+;PV−;IN;OUT.

- **États affichables :** closed;open;tripped;blown;deenergized. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** mechanical state only.
- **Compact :** Polarités + état mécanique.
- **Medium :** Entrée/sortie + polarités.
- **Expanded :** Marquages complets et état prouvé.
- **Priorité future :** `P1`.

### 19. `pv-conversion` — Régulation et conversion PV

- **Domaine :** PV/DC/AC. **Statut :** active. **Références legacy couvertes :** 8 (référence uniquement, import automatique = NON).

- **Silhouette :** Bloc convertisseur avec zones IN/OUT distinctes et flèche de conversion interne.
- **Gabarit :** `XL`. **Bornes :** `dc_or_pv_input_plus_ac_or_dc_output`. **Marquages persistants :** IN;OUT;PV+/PV−;L/N ou L1/L2/L3/N selon variante.

- **États affichables :** off;standby;converting;limited;disabled;invalid_input. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** status indicator only from result.
- **Compact :** IN/OUT + bornes indispensables.
- **Medium :** Sens de conversion + état.
- **Expanded :** Toutes bornes, rendements/valeurs si fournis par moteurs dédiés.
- **Priorité future :** `P1`.

### 20. `pv-storage-bus` — Stockage et bus DC PV

- **Domaine :** PV/DC. **Statut :** active. **Références legacy couvertes :** 5 (référence uniquement, import automatique = NON).

- **Silhouette :** Batterie/bus DC robuste, polarités très visibles, segments de bus distincts des fils.
- **Gabarit :** `L`. **Bornes :** `dc_pos;dc_neg;bus_variant`. **Marquages persistants :** +;−;SOC si disponible.

- **États affichables :** idle;charging;discharging;limited;disabled. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** charge-flow indicator only from result.
- **Compact :** Batterie/bus + polarités.
- **Medium :** État charge/décharge.
- **Expanded :** SOC/énergie uniquement si fournis par moteur énergie.
- **Priorité future :** `P1`.

### 21. `legacy-reference-only` — Legacy / compatibilité

- **Domaine :** N/A. **Statut :** excluded. **Références legacy couvertes :** 26 (référence uniquement, import automatique = NON).

- **Silhouette :** Aucun renderer F9 par défaut.
- **Gabarit :** `N/A`. **Bornes :** `N/A`. **Marquages persistants :** N/A.

- **États affichables :** N/A. Ces états doivent être fournis par les moteurs métier ou par un état de composant explicitement validé ; ils ne sont pas déduits du dessin.

- **Animation :** none.
- **Compact :** Non disponible.
- **Medium :** Non disponible.
- **Expanded :** Non disponible.
- **Priorité future :** `EXCLUDED`.

## 4. Interdictions

- aucune copie automatique des 217 éléments historiques ;
- aucun état « panne » générique peint en rouge si aucun moteur ne l’a établi ;
- aucune différence de forme entre la carte palette et le composant déposé qui empêcherait l’élève de les reconnaître comme le même objet ;
- aucune borne cachée par une décoration ;
- aucun texte minuscule obligatoire pour comprendre polarité, phase ou rôle ;
- aucune animation autonome déclenchée par un simple clic UI.
