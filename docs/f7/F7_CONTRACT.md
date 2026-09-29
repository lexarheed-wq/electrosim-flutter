# F7 — Contrat PV et énergie

## Domaine PV

- `CircuitState.mode == ElectricalMode.pv`.
- `SolverPV` est Dart pur et reçoit un `TopologyGraph` de même `circuitId` et `revision`.
- La source `pv_array` est distincte du réseau aval. F7 utilise un modèle MPP documenté : `mppVoltageV × mppCurrentA`, facteur d'irradiance linéaire et coefficients de température explicites.
- `irradianceWm2` et `cellTemperatureC` ne sont utilisés que parce que le modèle définit leurs effets mathématiques ; aucune grandeur environnementale décorative n'est générée.
- Le `pv_inverter` possède des bornes DC+/DC- et AC L/N explicites, des limites DC, une tension AC nominale, une puissance nominale et un rendement explicite.
- Une condition `disabled`, `openCircuit` ou `shortCircuit` de l'onduleur impose réellement une sortie AC nulle.
- `degraded` n'applique aucune valeur cachée : `deratingFactor` doit être fourni explicitement.
- Les charges F7 initiales sont des `pv_resistive_load` raccordées physiquement au bus AC de l'onduleur.
- Lorsque la puissance disponible est insuffisante, la tension de sortie est obtenue par `V = sqrt(P/G)` pour la conductance résistive raccordée ; aucune puissance fictive n'est conservée.

## Modèle MPP F7

À la température de référence `Tref` et irradiance de référence `Gref` :

`P_mpp_ref = V_mpp_ref × I_mpp_ref`

`P_available = P_mpp_ref × (G/Gref) × max(0, 1 + gammaP × (T-Tref))`

`V_mpp = V_mpp_ref × max(0, 1 + gammaV × (T-Tref))`

Ce modèle est une approximation de point de puissance maximale, pas une courbe I-V complète. Une courbe I-V plus avancée devra être introduite explicitement et testée si elle devient nécessaire.

## Énergie

- `EnergyEngine` n'invente aucune puissance. Il intègre uniquement un `EnergyPowerSample` physiquement équilibré.
- Pour le PV : `inputPowerW = pvDrawnPowerW`, `outputPowerW = inverterOutputPowerW`, `lossPowerW = inverterConversionLossW`.
- Bilan obligatoire : `input = output + loss` dans la tolérance.
- Intégration F7 : puissance supposée constante pendant l'intervalle explicite fourni à `advance`.
- `Wh = W × h`; `kWh = Wh / 1000`.
- Rendement instantané et cumulatif calculés à partir des puissances/énergies réelles.
- `EnergyHistory` est borné et immuable ; la persistance est reportée à F14.
