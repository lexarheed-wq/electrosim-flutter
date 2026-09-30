# F18-G0 — Matrice de parité composants V1 → Flutter

Cette matrice est un inventaire de décision, pas un mécanisme d’import. Les 217 entités historiques restent des références de connaissance.

## Résultat global

- Entités historiques : **217**
- REBUILD : **12**
- REPLACE : **11**
- DEFER : **168**
- RETIRE : **26**

Règle conservatrice G0 : seul un `modelType` déjà démontré dans la surface Flutter qualifiée est considéré comme support actuel. Les autres familles restent `DEFER` jusqu’à preuve moteur explicite.

## Comptage par catégorie

| Catégorie legacy | Nombre |
|---|---:|
| Appareils externes | 18 |
| Capacitifs & inductifs | 8 |
| Commande & détection | 29 |
| Commande moteur 3φ | 10 |
| Diodes & semi-conducteurs CC | 8 |
| Distribution & protection 3φ | 11 |
| Environnement PV | 3 |
| Legacy / compatibilité | 26 |
| Mesure | 3 |
| Mesure 3φ | 8 |
| Moteurs & charges 3φ | 7 |
| Prises | 4 |
| Production photovoltaïque | 7 |
| Protection & sectionnement PV | 4 |
| Protection CC / AC | 7 |
| Récepteurs & actionneurs CC / AC | 29 |
| Régulation & conversion PV | 8 |
| Résistifs & capteurs passifs | 9 |
| Sources AC 1φ | 2 |
| Sources CC | 8 |
| Sources triphasées | 3 |
| Stockage & bus DC PV | 5 |

## Correspondances Flutter déjà démontrées

| legacy_id | modelType Flutter | Gate |
|---|---|---|
| `pushNO` | `push_button_no` | G4 |
| `relayCoilDC` | `relay_coil` | G4 |
| `switchNO` | `switch` | G4 |
| `diodeRectifier` | `diode` | G4 |
| `breakerDC` | `breaker` | G4 |
| `fuseGeneric` | `fuse` | G4 |
| `buzzerDC` | `buzzer` | G4 |
| `fanDC` | `fan_dc` | G4 |
| `lampGeneric` | `lamp` | G4 |
| `motorDCGeneric` | `motor_dc` | G4 |
| `resistorGeneric` | `resistor` | G4 |
| `sourceDCGeneric` | `dc_voltage_source` | G4 |

Le détail exhaustif et normatif est dans `F18_PRODUCT_PARITY.csv`.
