# Dernier lot ElectroSim G5 : 11 composants et 3 compteurs

État au 12 octobre 2026 : développement local et preuves disponibles. Validation esthétique utilisateur en attente. Aucune fusion G5/main dans cette étape.

Les PNG sont des captures réelles Flutter, comprenant la palette en perspective et la platine de face. La vue de maintenance expose les bornes ; la vue alimentée utilise un circuit résolu. Elles ne prouvent pas une certification électrique, une fidélité parfaite à une photographie ou les performances à 400 composants.

**Ventilateur triphasé :** contrôle Flutter de rotation après correction exécuté avec succès (18 tests, dont les captures et les contrôles audio/mouvement).

| Composant | Vue de travail | Maintenance | Simulation |
|---|---|---|---|
| Réfrigérateur AC | [Palette et face](external-refrigerator-closed.png) | [Bornier](external-refrigerator-maintenance.png) | [Alimenté](external-refrigerator-running.png) |
| Réfrigérateur CC | [Palette et face](external-refrigerator-dc-closed.png) | [Bornier](external-refrigerator-dc-maintenance.png) | [Alimenté](external-refrigerator-dc-running.png) |
| Téléviseur | [Palette et face](external-tv-closed.png) | [Bornier](external-tv-maintenance.png) | [Alimenté](external-tv-running.png) |
| Ventilateur AC | [Palette et face](external-fan-ac1-closed.png) | [Bornier](external-fan-ac1-maintenance.png) | [Alimenté](external-fan-ac1-running.png) |
| Ventilateur triphasé | [Palette et face](external-fan-3p-closed.png) | [Bornier](external-fan-3p-maintenance.png) | [Alimenté](external-fan-3p-running.png) |
| Charge résistive PV | [Palette et face](pv-resistive-load-closed.png) | [Bornier](pv-resistive-load-maintenance.png) | [Alimenté](pv-resistive-load-running.png) |
| Source réseau triphasé | [Palette et face](source-ac3-grid-closed.png) | [Bornier](source-ac3-grid-maintenance.png) | [Alimenté](source-ac3-grid-running.png) |
| Alternateur | [Palette et face](source-ac3-alternator-closed.png) | [Bornier](source-ac3-alternator-maintenance.png) | [Alimenté](source-ac3-alternator-running.png) |
| Charge étoile | [Palette et face](load-wye-3p-closed.png) | [Bornier](load-wye-3p-maintenance.png) | [Alimenté](load-wye-3p-running.png) |
| Charge triangle | [Palette et face](load-delta-3p-closed.png) | [Bornier](load-delta-3p-maintenance.png) | [Alimenté](load-delta-3p-running.png) |
| Impédance | [Palette et face](impedance-closed.png) | [Bornier](impedance-maintenance.png) | [Alimenté](impedance-running.png) |
| Compteur AC | [Palette et face](energy-meter-ac1-closed.png) | [Bornier](energy-meter-ac1-maintenance.png) | [Alimenté](energy-meter-ac1-running.png) |
| Compteur triphasé | [Palette et face](energy-meter-ac3-closed.png) | [Bornier](energy-meter-ac3-maintenance.png) | [Alimenté](energy-meter-ac3-running.png) |
| Compteur PV (sortie AC) | [Palette et face](energy-meter-pv-closed.png) | [Bornier](energy-meter-pv-maintenance.png) | [Alimenté](energy-meter-pv-running.png) |

- [Vérifications et échecs historiques](verification-report.md)
- [Références et limites des modèles](references-and-limits.md)
- [Architecture atelier mixte CC/AC/AC3/PV](mixed-workshop-architecture.md) — proposition, non intégrée.
- [Provenance des rendus et captures](provenance.json)

Les trois compteurs affichent la puissance active et cumulent séparément E+ / E− en kWh suivant le temps simulé. Les index sont sauvegardés. Le compteur PV mesure la sortie AC de l'onduleur autonome ; il ne constitue pas encore une mesure d'injection réseau hybride.
