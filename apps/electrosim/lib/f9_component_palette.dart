import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_component_archetypes.dart';
import 'f18_component_asset_visual.dart';
import 'f18_industrial_dual_view.dart';
import 'reference_components/disjoncteur_3d.dart';

enum F9PaletteElementKind { source, component, instrument }

@immutable
class F9PaletteTerminalSpec {
  const F9PaletteTerminalSpec(
    this.label, {
    this.role = TerminalRole.generic,
    this.phase = PhaseTag.none,
    this.idSuffix,
  });

  final String label;
  final TerminalRole role;
  final PhaseTag phase;
  final String? idSuffix;
}

@immutable
class F9PaletteDefinition {
  const F9PaletteDefinition({
    required this.keyName,
    required this.title,
    required this.category,
    required this.modelType,
    required this.icon,
    required this.kind,
    required this.terminalLabels,
    this.terminals = const <F9PaletteTerminalSpec>[],
    this.defaultParameters = const <String, Object?>{},
    this.defaultControlState = const <String, Object?>{},
    this.supportedModes = const <ElectricalMode>{},
    this.searchOnlyModes = const <ElectricalMode>{},
    this.visualModelType,
    this.visualVariant,
    this.displayLabel,
    this.subtitle,
  });

  final String keyName;
  final String title;
  final String category;
  final String modelType;
  final IconData icon;
  final F9PaletteElementKind kind;
  final List<String> terminalLabels;
  final List<F9PaletteTerminalSpec> terminals;
  final Map<String, Object?> defaultParameters;
  final Map<String, Object?> defaultControlState;
  final Set<ElectricalMode> supportedModes;
  final Set<ElectricalMode> searchOnlyModes;
  final String? visualModelType;
  final String? visualVariant;
  final String? displayLabel;
  final String? subtitle;

  int get terminalCount =>
      terminals.isNotEmpty ? terminals.length : terminalLabels.length;

  String get renderedModelType => visualModelType ?? modelType;

  bool supportsMode(ElectricalMode mode) {
    if (supportedModes.isNotEmpty) return supportedModes.contains(mode);
    if (kind == F9PaletteElementKind.instrument) return true;
    if (kind == F9PaletteElementKind.source) {
      return switch (modelType) {
        'dc_voltage_source' ||
        'voltage_source' ||
        'dc_current_source' => mode == ElectricalMode.dc,
        'ac_voltage_source' || 'ac_current_source' =>
          mode == ElectricalMode.ac1 || mode == ElectricalMode.ac3,
        'pv_array' => mode == ElectricalMode.pv,
        _ => false,
      };
    }
    final ComponentModelContract? contract = CoreComponentModelContracts
        .registry
        .resolve(modelType);
    return contract?.supportsMode(mode) ?? false;
  }
}

const List<F9PaletteTerminalSpec> f9Motor3p6tTerminals =
    <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'U1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: 'u1',
      ),
      F9PaletteTerminalSpec(
        'V1',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: 'v1',
      ),
      F9PaletteTerminalSpec(
        'W1',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: 'w1',
      ),
      F9PaletteTerminalSpec(
        'U2',
        role: TerminalRole.loadT1,
        phase: PhaseTag.none,
        idSuffix: 'u2',
      ),
      F9PaletteTerminalSpec(
        'V2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.none,
        idSuffix: 'v2',
      ),
      F9PaletteTerminalSpec(
        'W2',
        role: TerminalRole.loadT3,
        phase: PhaseTag.none,
        idSuffix: 'w2',
      ),
    ];

const List<F9PaletteDefinition> f9PaletteCatalog = <F9PaletteDefinition>[
  F9PaletteDefinition(
    keyName: 'instrument-voltmeter',
    title: 'Voltmètre physique',
    category: 'Instruments de mesure',
    modelType: 'physical_voltmeter',
    icon: Icons.speed,
    kind: F9PaletteElementKind.instrument,
    terminalLabels: <String>[],
    searchOnlyModes: <ElectricalMode>{
      ElectricalMode.dc,
      ElectricalMode.ac1,
      ElectricalMode.ac3,
      ElectricalMode.pv,
    },
    subtitle: 'Sondes V/Ω et COM, impédance réelle',
  ),
  F9PaletteDefinition(
    keyName: 'instrument-ammeter',
    title: 'Ampèremètre physique',
    category: 'Instruments de mesure',
    modelType: 'physical_ammeter',
    icon: Icons.electric_meter,
    kind: F9PaletteElementKind.instrument,
    terminalLabels: <String>[],
    searchOnlyModes: <ElectricalMode>{
      ElectricalMode.dc,
      ElectricalMode.ac1,
      ElectricalMode.ac3,
      ElectricalMode.pv,
    },
    subtitle: 'Insertion en série, fusible et charge interne',
  ),
  F9PaletteDefinition(
    keyName: 'source-dc-24v',
    title: 'Source CC 24 V',
    category: 'Sources',
    modelType: 'dc_voltage_source',
    icon: Icons.battery_charging_full,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['+', '−'],
    subtitle: '24 V CC',
  ),
  F9PaletteDefinition(
    keyName: 'switch-no',
    title: 'Interrupteur NO',
    category: 'Commande',
    modelType: 'switch',
    icon: Icons.toggle_on_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    subtitle: 'Contact 2 bornes',
  ),
  F9PaletteDefinition(
    keyName: 'lamp',
    title: 'Lampe',
    category: 'Récepteurs',
    modelType: 'lamp',
    icon: Icons.lightbulb_outline,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'B'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{
      ComponentParameterKeys.resistanceOhm: 24.0,
      ReceiverNominalRating.voltageKey: 24.0,
      ReceiverNominalRating.currentKey: 1.0,
      ReceiverNominalRating.powerKey: 24.0,
      ComponentParameterKeys.thermalWithstandSeconds: 0.5,
    },
    displayLabel: 'Lampe 24 V',
    subtitle: 'Charge résistive',
  ),
  F9PaletteDefinition(
    keyName: 'lamp-ac1-230v',
    title: 'Lampe 230 V AC',
    category: 'Récepteurs',
    modelType: 'lamp',
    icon: Icons.lightbulb_outline,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'B'],
    supportedModes: <ElectricalMode>{
      ElectricalMode.ac1,
      ElectricalMode.ac3,
      ElectricalMode.pv,
    },
    defaultParameters: <String, Object?>{
      ComponentParameterKeys.resistanceOhm: 529.0,
      ReceiverNominalRating.voltageKey: 230.0,
      ReceiverNominalRating.currentKey: 0.43478260869565216,
      ReceiverNominalRating.powerKey: 100.0,
      ComponentParameterKeys.thermalWithstandSeconds: 0.5,
    },
    displayLabel: 'Lampe 230 V',
    subtitle: '230 V AC · 100 W',
  ),
  F9PaletteDefinition(
    keyName: 'resistor',
    title: 'Résistance',
    category: 'Passifs',
    modelType: 'resistor',
    icon: Icons.linear_scale,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    subtitle: '100 Ω',
  ),
  F9PaletteDefinition(
    keyName: 'breaker',
    title: 'Disjoncteur',
    category: 'Protection',
    modelType: 'breaker_dc',
    icon: Icons.electrical_services_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['IN', 'OUT'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{
      ProtectionRating.ratedCurrentKey: 10.0,
    },
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Protection 2 bornes',
  ),
  F9PaletteDefinition(
    keyName: 'lamp-dc-48v',
    title: 'Lampe 48 V CC',
    category: 'Récepteurs',
    modelType: 'lamp',
    icon: Icons.lightbulb_outline,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'B'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc, ElectricalMode.pv},
    searchOnlyModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{
      ComponentParameterKeys.resistanceOhm: 48.0,
      ReceiverNominalRating.voltageKey: 48.0,
      ReceiverNominalRating.currentKey: 1.0,
      ReceiverNominalRating.powerKey: 48.0,
      ComponentParameterKeys.thermalWithstandSeconds: 0.5,
    },
    visualVariant: 'dc-48v',
    displayLabel: 'Lampe 48 V',
    subtitle: '48 V CC · 48 W',
  ),
  F9PaletteDefinition(
    keyName: 'push-button-no',
    title: 'Bouton-poussoir NO',
    category: 'Commande',
    modelType: 'push_button_no',
    icon: Icons.radio_button_checked,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['13', '14'],
    subtitle: 'Commande momentanée',
  ),
  F9PaletteDefinition(
    keyName: 'push-button-nc',
    title: 'Bouton-poussoir NC',
    category: 'Commande',
    modelType: 'push_button_nc',
    icon: Icons.radio_button_unchecked,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['21', '22'],
    subtitle: 'Arrêt momentanée NC',
  ),
  F9PaletteDefinition(
    keyName: 'buzzer',
    title: 'Buzzer',
    category: 'Récepteurs',
    modelType: 'buzzer',
    icon: Icons.volume_up_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    subtitle: 'Avertisseur CC',
  ),
  F9PaletteDefinition(
    keyName: 'fuse',
    title: 'Fusible',
    category: 'Protection',
    modelType: 'fuse_dc',
    icon: Icons.horizontal_rule,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['IN', 'OUT'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{
      ProtectionRating.ratedCurrentKey: 10.0,
    },
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Protection simple',
  ),
  F9PaletteDefinition(
    keyName: 'diode',
    title: 'Diode redresseuse',
    category: 'Semi-conducteurs',
    modelType: 'diode',
    icon: Icons.play_arrow_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'K'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{'forwardVoltageV': 0.7},
    visualVariant: 'rectifier',
    displayLabel: 'Diode',
    subtitle: 'Vf 0,7 V',
  ),
  F9PaletteDefinition(
    keyName: 'diode-schottky',
    title: 'Diode Schottky',
    category: 'Semi-conducteurs',
    modelType: 'diode',
    icon: Icons.play_arrow_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'K'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{'forwardVoltageV': 0.3},
    visualVariant: 'schottky',
    displayLabel: 'Schottky',
    subtitle: 'Vf 0,3 V',
  ),
  F9PaletteDefinition(
    keyName: 'led-red',
    title: 'LED rouge',
    category: 'Semi-conducteurs',
    modelType: 'diode',
    icon: Icons.light_mode_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'K'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{
      'forwardVoltageV': 2.0,
      ComponentParameterKeys.seriesResistanceOhm: 5.0,
      ComponentParameterKeys.reverseBreakdownVoltageV: 5.0,
      ComponentParameterKeys.maxVoltageV: 3.0,
      ComponentParameterKeys.maxCurrentA: 0.020,
      ComponentParameterKeys.maxPowerW: 0.060,
      ComponentParameterKeys.thermalWithstandSeconds: 0.050,
    },
    visualVariant: 'led-red',
    displayLabel: 'LED rouge',
    subtitle: 'Vf 2,0 V',
  ),
  F9PaletteDefinition(
    keyName: 'led-green',
    title: 'LED verte',
    category: 'Semi-conducteurs',
    modelType: 'diode',
    icon: Icons.light_mode_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'K'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{
      'forwardVoltageV': 2.2,
      ComponentParameterKeys.seriesResistanceOhm: 5.0,
      ComponentParameterKeys.reverseBreakdownVoltageV: 5.0,
      ComponentParameterKeys.maxVoltageV: 3.2,
      ComponentParameterKeys.maxCurrentA: 0.020,
      ComponentParameterKeys.maxPowerW: 0.064,
      ComponentParameterKeys.thermalWithstandSeconds: 0.050,
    },
    visualVariant: 'led-green',
    displayLabel: 'LED verte',
    subtitle: 'Vf 2,2 V',
  ),
  F9PaletteDefinition(
    keyName: 'zener-5v1',
    title: 'Diode Zener 5,1 V',
    category: 'Semi-conducteurs',
    modelType: 'diode',
    icon: Icons.flash_on_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'K'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{
      'forwardVoltageV': 0.7,
      'reverseBreakdownVoltageV': 5.1,
    },
    visualVariant: 'zener',
    displayLabel: 'Zener 5,1 V',
    subtitle: 'Claquage inverse 5,1 V',
  ),
  F9PaletteDefinition(
    keyName: 'tvs-12v',
    title: 'Diode TVS 12 V',
    category: 'Semi-conducteurs',
    modelType: 'diode',
    icon: Icons.security_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A', 'K'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{
      'forwardVoltageV': 0.7,
      'reverseBreakdownVoltageV': 12.0,
    },
    visualVariant: 'tvs',
    displayLabel: 'TVS 12 V',
    subtitle: 'Protection surtension',
  ),
  F9PaletteDefinition(
    keyName: 'fan-dc',
    title: 'Ventilateur CC',
    category: 'Récepteurs',
    modelType: 'fan_dc',
    icon: Icons.air,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    subtitle: 'Actionneur rotatif',
  ),
  F9PaletteDefinition(
    keyName: 'motor-dc',
    title: 'Moteur CC',
    category: 'Récepteurs',
    modelType: 'motor_dc',
    icon: Icons.settings_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    subtitle: 'Moteur CC dynamique réduit · R, Ke, Kt, J',
    defaultParameters: <String, Object?>{
      ComponentParameterKeys.resistanceOhm: 8.0,
      ComponentParameterKeys.motorBackEmfVPerRadS: 0.1,
      ComponentParameterKeys.motorTorqueNmPerA: 0.1,
      ComponentParameterKeys.motorInertiaKgM2: 0.01,
      ComponentParameterKeys.motorFrictionNmPerRadS: 0.002,
      ComponentParameterKeys.motorLoadTorqueNm: 0.0,
      ReceiverNominalRating.voltageKey: 24.0,
      ReceiverNominalRating.currentKey: 3.0,
      ReceiverNominalRating.powerKey: 72.0,
    },
  ),
  F9PaletteDefinition(
    keyName: 'relay-coil',
    title: 'Bobine relais 24 V CC',
    category: 'Commande',
    modelType: 'relay_coil',
    icon: Icons.sync_alt,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['A1', 'A2'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{
      ComponentParameterKeys.resistanceOhm: 120.0,
      ComponentParameterKeys.coilPickupVoltageV: 18.0,
      ComponentParameterKeys.coilDropoutVoltageV: 6.0,
      ReceiverNominalRating.voltageKey: 24.0,
      ReceiverNominalRating.currentKey: 0.2,
      ReceiverNominalRating.powerKey: 4.8,
    },
    defaultControlState: <String, Object?>{'actuated': false},
    displayLabel: 'Bobine K',
    subtitle: '24 V CC · pickup 18 V',
  ),
  F9PaletteDefinition(
    keyName: 'relay-contact-no',
    title: 'Contact relais NO',
    category: 'Commande',
    modelType: 'relay_contact_no',
    icon: Icons.call_split_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['13', '14'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '13',
        role: TerminalRole.auxiliaryNormallyOpen,
        idSuffix: '13',
      ),
      F9PaletteTerminalSpec(
        '14',
        role: TerminalRole.auxiliaryNormallyOpen,
        idSuffix: '14',
      ),
    ],
    defaultControlState: <String, Object?>{'actuated': false},
    visualVariant: 'relay-no',
    displayLabel: 'Relais NO',
    subtitle: 'Lié à une bobine relais CC',
  ),
  F9PaletteDefinition(
    keyName: 'relay-contact-nc',
    title: 'Contact relais NC',
    category: 'Commande',
    modelType: 'relay_contact_nc',
    icon: Icons.call_merge_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['21', '22'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '21',
        role: TerminalRole.auxiliaryNormallyClosed,
        idSuffix: '21',
      ),
      F9PaletteTerminalSpec(
        '22',
        role: TerminalRole.auxiliaryNormallyClosed,
        idSuffix: '22',
      ),
    ],
    defaultControlState: <String, Object?>{'actuated': false},
    visualVariant: 'relay-nc',
    displayLabel: 'Relais NC',
    subtitle: 'Lié à une bobine relais CC',
  ),

  // C20 — V1 external-appliance parity through canonical electrical models.
  F9PaletteDefinition(
    keyName: 'external-crusher',
    title: 'Broyeur industriel',
    category: 'Appareils externes',
    modelType: 'motor_3p_6t',
    visualModelType: 'catalog_motor_driven_6t',
    visualVariant: 'crusher',
    displayLabel: 'Broyeur',
    icon: Icons.precision_manufacturing_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['U1', 'V1', 'W1', 'U2', 'V2', 'W2'],
    terminals: f9Motor3p6tTerminals,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 12.0,
      'inductanceH': 0.045,
      'ratedPowerW': 4000.0,
    },
    subtitle: 'Moteur 3φ · 4 kW',
  ),
  F9PaletteDefinition(
    keyName: 'external-air-conditioner',
    title: 'Climatiseur',
    category: 'Appareils externes',
    modelType: 'impedance',
    visualModelType: 'catalog_appliance_2t',
    visualVariant: 'air-conditioner',
    displayLabel: 'Climatiseur',
    icon: Icons.ac_unit_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 35.0,
      'reactanceOhm': 12.0,
    },
    subtitle: 'Charge AC 1φ',
  ),
  F9PaletteDefinition(
    keyName: 'external-compressor',
    title: 'Compresseur industriel',
    category: 'Appareils externes',
    modelType: 'motor_3p_6t',
    visualModelType: 'catalog_motor_driven_6t',
    visualVariant: 'compressor',
    displayLabel: 'Compresseur',
    icon: Icons.compress_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['U1', 'V1', 'W1', 'U2', 'V2', 'W2'],
    terminals: f9Motor3p6tTerminals,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 10.0,
      'inductanceH': 0.050,
      'ratedPowerW': 5500.0,
    },
    subtitle: 'Moteur 3φ · 5,5 kW',
  ),
  F9PaletteDefinition(
    keyName: 'external-freezer',
    title: 'Congélateur',
    category: 'Appareils externes',
    modelType: 'impedance',
    visualModelType: 'catalog_appliance_2t',
    visualVariant: 'freezer',
    displayLabel: 'Congélateur',
    icon: Icons.kitchen_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 170.0,
      'reactanceOhm': 35.0,
    },
    subtitle: 'Compresseur domestique AC',
  ),
  F9PaletteDefinition(
    keyName: 'external-conveyor',
    title: 'Convoyeur',
    category: 'Appareils externes',
    modelType: 'motor_3p_6t',
    visualModelType: 'catalog_motor_driven_6t',
    visualVariant: 'conveyor',
    displayLabel: 'Convoyeur',
    icon: Icons.conveyor_belt,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['U1', 'V1', 'W1', 'U2', 'V2', 'W2'],
    terminals: f9Motor3p6tTerminals,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 18.0,
      'inductanceH': 0.040,
      'ratedPowerW': 2200.0,
    },
    subtitle: 'Entraînement 3φ',
  ),
  F9PaletteDefinition(
    keyName: 'external-iron',
    title: 'Fer à repasser',
    category: 'Appareils externes',
    modelType: 'resistor',
    visualModelType: 'catalog_heater',
    visualVariant: 'iron',
    displayLabel: 'Fer',
    icon: Icons.iron_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    defaultParameters: <String, Object?>{'resistanceOhm': 44.1},
    subtitle: '≈ 1,2 kW à 230 V',
  ),
  F9PaletteDefinition(
    keyName: 'external-mixer',
    title: 'Mélangeur industriel',
    category: 'Appareils externes',
    modelType: 'motor_3p_6t',
    visualModelType: 'catalog_motor_driven_6t',
    visualVariant: 'mixer',
    displayLabel: 'Mélangeur',
    icon: Icons.blender_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['U1', 'V1', 'W1', 'U2', 'V2', 'W2'],
    terminals: f9Motor3p6tTerminals,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 15.0,
      'inductanceH': 0.045,
      'ratedPowerW': 3000.0,
    },
    subtitle: 'Moteur 3φ',
  ),
  F9PaletteDefinition(
    keyName: 'external-computer',
    title: 'Ordinateur',
    category: 'Appareils externes',
    modelType: 'impedance',
    visualModelType: 'catalog_appliance_2t',
    visualVariant: 'computer',
    displayLabel: 'Ordinateur',
    icon: Icons.computer_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 260.0,
      'reactanceOhm': -30.0,
    },
    subtitle: 'Charge électronique AC',
  ),
  F9PaletteDefinition(
    keyName: 'external-pump-3p',
    title: 'Pompe industrielle',
    category: 'Appareils externes',
    modelType: 'motor_3p_6t',
    visualModelType: 'catalog_motor_driven_6t',
    visualVariant: 'pump',
    displayLabel: 'Pompe 3φ',
    icon: Icons.water_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['U1', 'V1', 'W1', 'U2', 'V2', 'W2'],
    terminals: f9Motor3p6tTerminals,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 16.0,
      'inductanceH': 0.040,
      'ratedPowerW': 3000.0,
    },
    subtitle: 'Pompe moteur 3φ',
  ),
  F9PaletteDefinition(
    keyName: 'external-pump-ac1',
    title: 'Pompe monophasée',
    category: 'Appareils externes',
    modelType: 'impedance',
    visualModelType: 'catalog_motor_driven_2t',
    visualVariant: 'pump',
    displayLabel: 'Pompe 1φ',
    icon: Icons.water_drop_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 42.0,
      'reactanceOhm': 22.0,
    },
    subtitle: 'Moteur monophasé',
  ),
  F9PaletteDefinition(
    keyName: 'external-solar-pump',
    title: 'Pompe solaire DC',
    category: 'Appareils externes',
    modelType: 'motor_dc',
    visualModelType: 'catalog_motor_driven_2t',
    visualVariant: 'pump',
    displayLabel: 'Pompe DC',
    icon: Icons.solar_power_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{'resistanceOhm': 8.0},
    subtitle: 'Pompe CC',
  ),
  F9PaletteDefinition(
    keyName: 'external-refrigerator',
    title: 'Réfrigérateur',
    category: 'Appareils externes',
    modelType: 'impedance',
    visualModelType: 'catalog_appliance_2t',
    visualVariant: 'refrigerator',
    displayLabel: 'Réfrigérateur',
    icon: Icons.kitchen_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 205.0,
      'reactanceOhm': 38.0,
    },
    subtitle: 'Charge frigorifique AC',
  ),
  F9PaletteDefinition(
    keyName: 'external-refrigerator-dc',
    title: 'Réfrigérateur solaire DC',
    category: 'Appareils externes',
    modelType: 'motor_dc',
    visualModelType: 'catalog_appliance_2t',
    visualVariant: 'refrigerator-dc',
    displayLabel: 'Réfrigérateur DC',
    icon: Icons.kitchen_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{'resistanceOhm': 12.0},
    subtitle: 'Compresseur CC',
  ),
  F9PaletteDefinition(
    keyName: 'external-tv',
    title: 'Télévision',
    category: 'Appareils externes',
    modelType: 'impedance',
    visualModelType: 'catalog_appliance_2t',
    visualVariant: 'television',
    displayLabel: 'Télévision',
    icon: Icons.tv_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 520.0,
      'reactanceOhm': -20.0,
    },
    subtitle: 'Charge électronique AC',
  ),
  F9PaletteDefinition(
    keyName: 'external-fan-ac1',
    title: 'Ventilateur domestique',
    category: 'Appareils externes',
    modelType: 'impedance',
    visualModelType: 'catalog_motor_driven_2t',
    visualVariant: 'fan',
    displayLabel: 'Ventilateur 1φ',
    icon: Icons.air,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 180.0,
      'reactanceOhm': 65.0,
    },
    subtitle: 'Moteur AC 1φ',
  ),
  F9PaletteDefinition(
    keyName: 'external-fan-3p',
    title: 'Ventilateur industriel',
    category: 'Appareils externes',
    modelType: 'motor_3p_6t',
    visualModelType: 'catalog_motor_driven_6t',
    visualVariant: 'fan',
    displayLabel: 'Ventilateur 3φ',
    icon: Icons.air,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['U1', 'V1', 'W1', 'U2', 'V2', 'W2'],
    terminals: f9Motor3p6tTerminals,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    defaultParameters: <String, Object?>{
      'resistanceOhm': 24.0,
      'inductanceH': 0.035,
      'ratedPowerW': 1500.0,
    },
    subtitle: 'Moteur 3φ',
  ),

  // C15 Wave 2 — sources AC/CC and photovoltaic chain.
  F9PaletteDefinition(
    keyName: 'source-dc-current',
    title: 'Source de courant CC',
    category: 'Sources',
    modelType: 'dc_current_source',
    icon: Icons.arrow_upward,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['+', '−'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    defaultParameters: <String, Object?>{'currentA': 1.0},
    visualVariant: 'dc-current',
    displayLabel: 'Source I CC',
    subtitle: '1 A CC réglable',
  ),
  F9PaletteDefinition(
    keyName: 'source-ac1-230v',
    title: 'Source AC 230 V',
    category: 'Sources AC',
    modelType: 'ac_voltage_source',
    icon: Icons.ssid_chart,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
        idSuffix: 'l',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{'voltageRmsV': 230.0, 'phaseDeg': 0.0},
    visualVariant: 'ac-1p',
    displayLabel: 'Source 230 V~',
    subtitle: '230 V RMS · 50 Hz',
  ),
  F9PaletteDefinition(
    keyName: 'source-ac1-current',
    title: 'Source de courant AC',
    category: 'Sources AC',
    modelType: 'ac_current_source',
    icon: Icons.multiline_chart,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
        idSuffix: 'l',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{'currentRmsA': 1.0, 'phaseDeg': 0.0},
    visualVariant: 'ac-current',
    displayLabel: 'Source I~',
    subtitle: '1 A RMS · 50 Hz',
  ),
  F9PaletteDefinition(
    keyName: 'source-ac3-l1',
    title: 'Réseau triphasé — L1',
    category: 'Sources 3φ',
    modelType: 'ac_voltage_source',
    icon: Icons.looks_one_outlined,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['L1', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L1',
        role: TerminalRole.phaseL1,
        phase: PhaseTag.l1,
        idSuffix: 'l1',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{'voltageRmsV': 230.0, 'phaseDeg': 0.0},
    visualVariant: 'ac-l1',
    displayLabel: 'Réseau L1',
    subtitle: 'L1-N · 230 V · 0°',
  ),
  F9PaletteDefinition(
    keyName: 'source-ac3-l2',
    title: 'Réseau triphasé — L2',
    category: 'Sources 3φ',
    modelType: 'ac_voltage_source',
    icon: Icons.looks_two_outlined,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['L2', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L2',
        role: TerminalRole.phaseL2,
        phase: PhaseTag.l2,
        idSuffix: 'l2',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{
      'voltageRmsV': 230.0,
      'phaseDeg': -120.0,
    },
    visualVariant: 'ac-l2',
    displayLabel: 'Réseau L2',
    subtitle: 'L2-N · 230 V · −120°',
  ),
  F9PaletteDefinition(
    keyName: 'source-ac3-l3',
    title: 'Réseau triphasé — L3',
    category: 'Sources 3φ',
    modelType: 'ac_voltage_source',
    icon: Icons.looks_3_outlined,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['L3', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L3',
        role: TerminalRole.phaseL3,
        phase: PhaseTag.l3,
        idSuffix: 'l3',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{
      'voltageRmsV': 230.0,
      'phaseDeg': 120.0,
    },
    visualVariant: 'ac-l3',
    displayLabel: 'Réseau L3',
    subtitle: 'L3-N · 230 V · +120°',
  ),
  F9PaletteDefinition(
    keyName: 'pv-array',
    title: 'Champ photovoltaïque',
    category: 'Photovoltaïque',
    modelType: 'pv_array',
    icon: Icons.solar_power_outlined,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['+', '−'],
    supportedModes: <ElectricalMode>{ElectricalMode.pv},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'pos',
      ),
      F9PaletteTerminalSpec(
        '−',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'neg',
      ),
    ],
    defaultParameters: <String, Object?>{
      'mppVoltageV': 360.0,
      'mppCurrentA': 10.0,
      'powerTemperatureCoefficientPerC': -0.004,
      'voltageTemperatureCoefficientPerC': -0.003,
    },
    visualVariant: 'pv-array',
    displayLabel: 'Champ PV',
    subtitle: '360 V MPP · 10 A',
  ),
  F9PaletteDefinition(
    keyName: 'pv-controller-mppt',
    title: 'Régulateur solaire MPPT',
    category: 'Photovoltaïque',
    modelType: 'pv_controller',
    icon: Icons.tune_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['PV+', 'PV−', 'BAT+', 'BAT−'],
    supportedModes: <ElectricalMode>{ElectricalMode.pv},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'PV+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'pv-pos',
      ),
      F9PaletteTerminalSpec(
        'PV−',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'pv-neg',
      ),
      F9PaletteTerminalSpec(
        'BAT+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'bat-pos',
      ),
      F9PaletteTerminalSpec(
        'BAT−',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'bat-neg',
      ),
    ],
    defaultParameters: <String, Object?>{
      'outputVoltageV': 48.0,
      'maxOutputCurrentA': 60.0,
      'efficiency': 0.97,
      'controllerType': 'mppt',
      'maxPvInputVoltageV': 450.0,
    },
    visualVariant: 'pv-mppt',
    displayLabel: 'Régulateur MPPT',
    subtitle: '48 V · 60 A · η 97 %',
  ),
  F9PaletteDefinition(
    keyName: 'pv-controller-pwm',
    title: 'Régulateur solaire PWM',
    category: 'Photovoltaïque',
    modelType: 'pv_controller',
    icon: Icons.tune_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['PV+', 'PV−', 'BAT+', 'BAT−'],
    supportedModes: <ElectricalMode>{ElectricalMode.pv},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'PV+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'pv-pos',
      ),
      F9PaletteTerminalSpec(
        'PV−',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'pv-neg',
      ),
      F9PaletteTerminalSpec(
        'BAT+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'bat-pos',
      ),
      F9PaletteTerminalSpec(
        'BAT−',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'bat-neg',
      ),
    ],
    defaultParameters: <String, Object?>{
      'outputVoltageV': 48.0,
      'maxOutputCurrentA': 40.0,
      'efficiency': 0.92,
      'controllerType': 'pwm',
      'maxPvInputVoltageV': 60.0,
    },
    visualVariant: 'pv-pwm',
    displayLabel: 'Régulateur PWM',
    subtitle: '48 V · 40 A · η 92 %',
  ),
  F9PaletteDefinition(
    keyName: 'pv-battery',
    title: 'Batterie photovoltaïque',
    category: 'Photovoltaïque',
    modelType: 'pv_battery',
    icon: Icons.battery_full,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['+', '−'],
    supportedModes: <ElectricalMode>{ElectricalMode.dc, ElectricalMode.pv},
    searchOnlyModes: <ElectricalMode>{ElectricalMode.dc},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'pos',
      ),
      F9PaletteTerminalSpec(
        '−',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'neg',
      ),
    ],
    defaultParameters: <String, Object?>{
      'nominalVoltageV': 48.0,
      'internalResistanceOhm': 0.08,
      'capacityAh': 100.0,
      'initialSoc': 0.60,
      'minSoc': 0.10,
      'maxSoc': 0.95,
      'maxChargeCurrentA': 30.0,
      'maxDischargeCurrentA': 60.0,
      'chargeEfficiency': 0.95,
      'dischargeEfficiency': 0.95,
    },
    visualVariant: 'pv-battery',
    displayLabel: 'Batterie PV',
    subtitle: '48 V · 100 Ah',
  ),
  F9PaletteDefinition(
    keyName: 'pv-inverter',
    title: 'Onduleur solaire 1φ',
    category: 'Photovoltaïque',
    modelType: 'pv_inverter',
    icon: Icons.swap_horiz,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['DC+', 'DC−', 'L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.pv},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'DC+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'dc-pos',
      ),
      F9PaletteTerminalSpec(
        'DC−',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'dc-neg',
      ),
      F9PaletteTerminalSpec(
        'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
        idSuffix: 'l',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{
      'minDcVoltageV': 40.0,
      'maxDcVoltageV': 60.0,
      'nominalAcVoltageV': 230.0,
      'ratedAcPowerW': 3000.0,
      'efficiency': 0.96,
    },
    visualVariant: 'pv-inverter-1p',
    displayLabel: 'Onduleur PV',
    subtitle: '48 V CC → 230 V AC · 3 kW · η 96 %',
  ),
  F9PaletteDefinition(
    keyName: 'pv-resistive-load',
    title: 'Charge AC PV',
    category: 'Photovoltaïque',
    modelType: 'pv_resistive_load',
    icon: Icons.power_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.pv},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
        idSuffix: 'l',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{'resistanceOhm': 52.9},
    visualVariant: 'pv-load',
    displayLabel: 'Charge PV',
    subtitle: '≈1 kW à 230 V',
  ),

  F9PaletteDefinition(
    keyName: 'source-ac3-grid',
    title: 'Réseau triphasé 400/230 V',
    category: 'Sources 3φ',
    modelType: 'ac3_voltage_source',
    icon: Icons.electrical_services_outlined,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['L1', 'L2', 'L3', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L1',
        role: TerminalRole.phaseL1,
        phase: PhaseTag.l1,
        idSuffix: 'l1',
      ),
      F9PaletteTerminalSpec(
        'L2',
        role: TerminalRole.phaseL2,
        phase: PhaseTag.l2,
        idSuffix: 'l2',
      ),
      F9PaletteTerminalSpec(
        'L3',
        role: TerminalRole.phaseL3,
        phase: PhaseTag.l3,
        idSuffix: 'l3',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{'phaseVoltageRmsV': 230.0},
    visualVariant: 'ac3-grid',
    displayLabel: 'Réseau 3φ',
    subtitle: 'L-L 400 V · L-N 230 V · 50 Hz',
  ),
  F9PaletteDefinition(
    keyName: 'source-ac3-alternator',
    title: 'Alternateur triphasé',
    category: 'Sources 3φ',
    modelType: 'ac3_voltage_source',
    visualModelType: 'ac3_voltage_source',
    visualVariant: 'ac3-generator',
    displayLabel: 'Alternateur 3φ',
    icon: Icons.cyclone_outlined,
    kind: F9PaletteElementKind.source,
    terminalLabels: <String>['L1', 'L2', 'L3', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L1',
        role: TerminalRole.phaseL1,
        phase: PhaseTag.l1,
        idSuffix: 'l1',
      ),
      F9PaletteTerminalSpec(
        'L2',
        role: TerminalRole.phaseL2,
        phase: PhaseTag.l2,
        idSuffix: 'l2',
      ),
      F9PaletteTerminalSpec(
        'L3',
        role: TerminalRole.phaseL3,
        phase: PhaseTag.l3,
        idSuffix: 'l3',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{'phaseVoltageRmsV': 230.0},
    subtitle: 'Source 3φ synchrone idéale',
  ),

  // C17 — physical three-phase receivers.
  F9PaletteDefinition(
    keyName: 'motor-3p-6t',
    title: 'Moteur triphasé 6 bornes',
    category: 'Moteurs 3φ',
    modelType: 'motor_3p_6t',
    icon: Icons.settings_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['U1', 'V1', 'W1', 'U2', 'V2', 'W2'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminals: f9Motor3p6tTerminals,
    defaultParameters: <String, Object?>{
      'resistanceOhm': 18.0,
      'inductanceH': 0.035,
      'ratedPowerW': 2200.0,
      'ratedVoltageV': 400.0,
      'ratedDeltaVoltageV': 230.0,
      'ratedStarVoltageV': 400.0,
      'ratedSpeedRpm': 1420.0,
    },
    visualVariant: 'motor-3p',
    displayLabel: 'Moteur 3φ',
    subtitle: '6 bornes · couplage externe Y/Δ',
  ),
  F9PaletteDefinition(
    keyName: 'load-wye-3p',
    title: 'Charge triphasée Y (3 impédances)',
    category: 'Charges 3φ',
    modelType: 'load_wye_3p',
    icon: Icons.change_history_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L1', 'L2', 'L3', 'N'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: 'l1',
      ),
      F9PaletteTerminalSpec(
        'L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: 'l2',
      ),
      F9PaletteTerminalSpec(
        'L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: 'l3',
      ),
      F9PaletteTerminalSpec(
        'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n',
      ),
    ],
    defaultParameters: <String, Object?>{
      'resistanceOhm': 46.0,
      'inductanceH': 0.0,
    },
    visualVariant: 'load-wye',
    displayLabel: 'Charge Y',
    subtitle: '3 branches phase-point étoile · neutre optionnel',
  ),
  F9PaletteDefinition(
    keyName: 'load-delta-3p',
    title: 'Charge triphasée Δ (3 impédances)',
    category: 'Charges 3φ',
    modelType: 'load_delta_3p',
    icon: Icons.change_history,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L1', 'L2', 'L3'],
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: 'l1',
      ),
      F9PaletteTerminalSpec(
        'L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: 'l2',
      ),
      F9PaletteTerminalSpec(
        'L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: 'l3',
      ),
    ],
    defaultParameters: <String, Object?>{
      'resistanceOhm': 80.0,
      'inductanceH': 0.0,
    },
    visualVariant: 'load-delta',
    displayLabel: 'Charge Δ',
    subtitle: '3 branches entre phases · sans neutre',
  ),

  // C14 Wave 1 — canonical models already supported by the V2 electrical core.
  F9PaletteDefinition(
    keyName: 'capacitor',
    title: 'Condensateur',
    category: 'Passifs',
    modelType: 'capacitor',
    icon: Icons.view_column_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    defaultParameters: <String, Object?>{'capacitanceF': 0.0001},
    subtitle: '100 µF — AC1/AC3',
  ),
  F9PaletteDefinition(
    keyName: 'inductor',
    title: 'Inductance',
    category: 'Passifs',
    modelType: 'inductor',
    icon: Icons.waves_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    defaultParameters: <String, Object?>{'inductanceH': 0.1},
    subtitle: '100 mH — AC1/AC3',
  ),
  F9PaletteDefinition(
    keyName: 'impedance',
    title: 'Impédance',
    category: 'Passifs',
    modelType: 'impedance',
    icon: Icons.show_chart,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['1', '2'],
    defaultParameters: <String, Object?>{
      'resistanceOhm': 20.0,
      'reactanceOhm': 10.0,
    },
    subtitle: 'R + jX — AC1/AC3',
  ),
  F9PaletteDefinition(
    keyName: 'rcd-2p-ac1',
    title: 'Différentiel 2P AC',
    category: 'Protection',
    modelType: 'rcd_2p_ac1',
    icon: Icons.electrical_services_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['N entrée', 'L entrée', 'N sortie', 'L sortie'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        'N entrée',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n_in',
      ),
      F9PaletteTerminalSpec(
        'L entrée',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: 'l_in',
      ),
      F9PaletteTerminalSpec(
        'N sortie',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n_out',
      ),
      F9PaletteTerminalSpec(
        'L sortie',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: 'l_out',
      ),
    ],
    defaultParameters: <String, Object?>{
      ProtectionRating.ratedCurrentKey: 16.0,
      ComponentParameterKeys.residualTripCurrentA: 0.03,
    },
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Protection différentielle à 4 bornes · IΔn 30 mA',
  ),
  F9PaletteDefinition(
    keyName: 'breaker-ac1',
    title: 'Disjoncteur AC 1φ',
    category: 'Protection',
    modelType: 'breaker_ac1',
    icon: Icons.electrical_services_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'T'],
    defaultParameters: <String, Object?>{
      ProtectionRating.ratedCurrentKey: 10.0,
    },
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Protection monophasée',
  ),
  F9PaletteDefinition(
    keyName: 'fuse-ac1',
    title: 'Fusible AC 1φ',
    category: 'Protection',
    modelType: 'fuse_ac1',
    icon: Icons.horizontal_rule,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['L', 'T'],
    defaultParameters: <String, Object?>{
      ProtectionRating.ratedCurrentKey: 10.0,
    },
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Fusible monophasé',
  ),
  F9PaletteDefinition(
    keyName: 'aux-contact-no',
    title: 'Contact auxiliaire NO',
    category: 'Commande',
    modelType: 'contactor_aux_no',
    icon: Icons.call_split_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['13', '14'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '13',
        role: TerminalRole.auxiliaryNormallyOpen,
        idSuffix: '13',
      ),
      F9PaletteTerminalSpec(
        '14',
        role: TerminalRole.auxiliaryNormallyOpen,
        idSuffix: '14',
      ),
    ],
    defaultControlState: <String, Object?>{'actuated': false},
    subtitle: 'Contact lié au contacteur',
  ),
  F9PaletteDefinition(
    keyName: 'aux-contact-nc',
    title: 'Contact auxiliaire NC',
    category: 'Commande',
    modelType: 'contactor_aux_nc',
    icon: Icons.call_merge_outlined,
    kind: F9PaletteElementKind.component,
    terminalLabels: <String>['21', '22'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '21',
        role: TerminalRole.auxiliaryNormallyClosed,
        idSuffix: '21',
      ),
      F9PaletteTerminalSpec(
        '22',
        role: TerminalRole.auxiliaryNormallyClosed,
        idSuffix: '22',
      ),
    ],
    defaultControlState: <String, Object?>{'actuated': false},
    subtitle: 'Contact lié au contacteur',
  ),
  F9PaletteDefinition(
    keyName: 'contactor-ac1',
    title: 'Contacteur AC 1φ',
    category: 'Commande',
    modelType: 'contactor_ac1',
    icon: Icons.hub_outlined,
    kind: F9PaletteElementKind.component,
    supportedModes: <ElectricalMode>{ElectricalMode.ac1},
    terminalLabels: <String>['1L1', '2T1', 'A1', 'A2'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        'A1',
        role: TerminalRole.coilA1,
        phase: PhaseTag.l1,
        idSuffix: 'a1',
      ),
      F9PaletteTerminalSpec(
        'A2',
        role: TerminalRole.coilA2,
        phase: PhaseTag.neutral,
        idSuffix: 'a2',
      ),
    ],
    defaultParameters: <String, Object?>{
      'coilResistanceOhm': 1000.0,
      'coilInductanceH': 0.0,
      'coilPickupVoltageV': 180.0,
      'coilDropoutVoltageV': 100.0,
    },
    defaultControlState: <String, Object?>{'actuated': false},
    subtitle: 'Puissance + bobine A1/A2',
  ),
  F9PaletteDefinition(
    keyName: 'contactor-3p',
    title: 'Contacteur 3P',
    category: 'Triphasé',
    modelType: 'contactor_3p',
    icon: Icons.hub,
    kind: F9PaletteElementKind.component,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminalLabels: <String>[
      '1L1',
      '3L2',
      '5L3',
      '2T1',
      '4T2',
      '6T3',
      'A1',
      'A2',
    ],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '3L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: '3l2',
      ),
      F9PaletteTerminalSpec(
        '5L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: '5l3',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        '4T2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.l2,
        idSuffix: '4t2',
      ),
      F9PaletteTerminalSpec(
        '6T3',
        role: TerminalRole.loadT3,
        phase: PhaseTag.l3,
        idSuffix: '6t3',
      ),
      F9PaletteTerminalSpec(
        'A1',
        role: TerminalRole.coilA1,
        phase: PhaseTag.l1,
        idSuffix: 'a1',
      ),
      F9PaletteTerminalSpec(
        'A2',
        role: TerminalRole.coilA2,
        phase: PhaseTag.neutral,
        idSuffix: 'a2',
      ),
    ],
    defaultParameters: <String, Object?>{
      'coilResistanceOhm': 1000.0,
      'coilInductanceH': 0.0,
      'coilPickupVoltageV': 180.0,
      'coilDropoutVoltageV': 100.0,
    },
    defaultControlState: <String, Object?>{'actuated': false},
    subtitle: '3 pôles + bobine A1/A2',
  ),
  F9PaletteDefinition(
    keyName: 'breaker-3p',
    title: 'Disjoncteur 3P',
    category: 'Triphasé',
    modelType: 'breaker_3p',
    icon: Icons.electrical_services,
    kind: F9PaletteElementKind.component,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminalLabels: <String>['1L1', '3L2', '5L3', '2T1', '4T2', '6T3'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '3L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: '3l2',
      ),
      F9PaletteTerminalSpec(
        '5L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: '5l3',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        '4T2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.l2,
        idSuffix: '4t2',
      ),
      F9PaletteTerminalSpec(
        '6T3',
        role: TerminalRole.loadT3,
        phase: PhaseTag.l3,
        idSuffix: '6t3',
      ),
    ],
    defaultParameters: <String, Object?>{
      ProtectionRating.ratedCurrentKey: 10.0,
    },
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Protection triphasée',
  ),
  F9PaletteDefinition(
    keyName: 'isolator-3p',
    title: 'Sectionneur 3P',
    category: 'Distribution 3φ',
    modelType: 'isolator_3p',
    icon: Icons.toggle_off_outlined,
    kind: F9PaletteElementKind.component,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminalLabels: <String>['1L1', '3L2', '5L3', '2T1', '4T2', '6T3'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '3L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: '3l2',
      ),
      F9PaletteTerminalSpec(
        '5L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: '5l3',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        '4T2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.l2,
        idSuffix: '4t2',
      ),
      F9PaletteTerminalSpec(
        '6T3',
        role: TerminalRole.loadT3,
        phase: PhaseTag.l3,
        idSuffix: '6t3',
      ),
    ],
    defaultControlState: <String, Object?>{'closed': true},
    subtitle: 'Coupure générale triphasée',
  ),
  F9PaletteDefinition(
    keyName: 'isolator-4p',
    title: 'Sectionneur 4P',
    category: 'Distribution 3φ',
    modelType: 'isolator_4p',
    icon: Icons.toggle_off,
    kind: F9PaletteElementKind.component,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminalLabels: <String>[
      '1L1',
      '3L2',
      '5L3',
      'N IN',
      '2T1',
      '4T2',
      '6T3',
      'N OUT',
    ],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '3L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: '3l2',
      ),
      F9PaletteTerminalSpec(
        '5L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: '5l3',
      ),
      F9PaletteTerminalSpec(
        'N IN',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n-in',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        '4T2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.l2,
        idSuffix: '4t2',
      ),
      F9PaletteTerminalSpec(
        '6T3',
        role: TerminalRole.loadT3,
        phase: PhaseTag.l3,
        idSuffix: '6t3',
      ),
      F9PaletteTerminalSpec(
        'N OUT',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n-out',
      ),
    ],
    defaultControlState: <String, Object?>{'closed': true},
    subtitle: 'L1/L2/L3/N',
  ),
  F9PaletteDefinition(
    keyName: 'breaker-4p',
    title: 'Disjoncteur 4P',
    category: 'Distribution 3φ',
    modelType: 'breaker_4p',
    icon: Icons.electrical_services,
    kind: F9PaletteElementKind.component,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminalLabels: <String>[
      '1L1',
      '3L2',
      '5L3',
      'N IN',
      '2T1',
      '4T2',
      '6T3',
      'N OUT',
    ],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '3L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: '3l2',
      ),
      F9PaletteTerminalSpec(
        '5L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: '5l3',
      ),
      F9PaletteTerminalSpec(
        'N IN',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n-in',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        '4T2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.l2,
        idSuffix: '4t2',
      ),
      F9PaletteTerminalSpec(
        '6T3',
        role: TerminalRole.loadT3,
        phase: PhaseTag.l3,
        idSuffix: '6t3',
      ),
      F9PaletteTerminalSpec(
        'N OUT',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n-out',
      ),
    ],
    defaultParameters: <String, Object?>{'ratedCurrentA': 16.0},
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Protection L1/L2/L3/N',
  ),
  F9PaletteDefinition(
    keyName: 'terminal-block-dc-5',
    title: 'Bornier CC +/−/PE',
    category: 'Distribution CC',
    modelType: 'terminal_block_5',
    icon: Icons.view_week_outlined,
    kind: F9PaletteElementKind.component,
    supportedModes: <ElectricalMode>{ElectricalMode.dc},
    terminalLabels: <String>[
      '+1 IN',
      '+2 IN',
      '−1 IN',
      '−2 IN',
      'PE IN',
      '+1 OUT',
      '+2 OUT',
      '−1 OUT',
      '−2 OUT',
      'PE OUT',
    ],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '+1 IN',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'plus1-in',
      ),
      F9PaletteTerminalSpec(
        '+2 IN',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'plus2-in',
      ),
      F9PaletteTerminalSpec(
        '−1 IN',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'minus1-in',
      ),
      F9PaletteTerminalSpec(
        '−2 IN',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'minus2-in',
      ),
      F9PaletteTerminalSpec(
        'PE IN',
        role: TerminalRole.protectiveEarth,
        phase: PhaseTag.protectiveEarth,
        idSuffix: 'pe-in',
      ),
      F9PaletteTerminalSpec(
        '+1 OUT',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'plus1-out',
      ),
      F9PaletteTerminalSpec(
        '+2 OUT',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
        idSuffix: 'plus2-out',
      ),
      F9PaletteTerminalSpec(
        '−1 OUT',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'minus1-out',
      ),
      F9PaletteTerminalSpec(
        '−2 OUT',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
        idSuffix: 'minus2-out',
      ),
      F9PaletteTerminalSpec(
        'PE OUT',
        role: TerminalRole.protectiveEarth,
        phase: PhaseTag.protectiveEarth,
        idSuffix: 'pe-out',
      ),
    ],
    visualVariant: 'dc',
    displayLabel: 'Bornier CC',
    subtitle: '2 départs +/− et conducteur PE',
  ),
  F9PaletteDefinition(
    keyName: 'terminal-block-5',
    title: 'Bornier L1/L2/L3/N/PE',
    category: 'Distribution 3φ',
    modelType: 'terminal_block_5',
    icon: Icons.view_week_outlined,
    kind: F9PaletteElementKind.component,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminalLabels: <String>[
      'L1 IN',
      'L2 IN',
      'L3 IN',
      'N IN',
      'PE IN',
      'L1 OUT',
      'L2 OUT',
      'L3 OUT',
      'N OUT',
      'PE OUT',
    ],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec('L1 IN', phase: PhaseTag.l1, idSuffix: 'l1-in'),
      F9PaletteTerminalSpec('L2 IN', phase: PhaseTag.l2, idSuffix: 'l2-in'),
      F9PaletteTerminalSpec('L3 IN', phase: PhaseTag.l3, idSuffix: 'l3-in'),
      F9PaletteTerminalSpec(
        'N IN',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n-in',
      ),
      F9PaletteTerminalSpec(
        'PE IN',
        phase: PhaseTag.protectiveEarth,
        idSuffix: 'pe-in',
      ),
      F9PaletteTerminalSpec('L1 OUT', phase: PhaseTag.l1, idSuffix: 'l1-out'),
      F9PaletteTerminalSpec('L2 OUT', phase: PhaseTag.l2, idSuffix: 'l2-out'),
      F9PaletteTerminalSpec('L3 OUT', phase: PhaseTag.l3, idSuffix: 'l3-out'),
      F9PaletteTerminalSpec(
        'N OUT',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
        idSuffix: 'n-out',
      ),
      F9PaletteTerminalSpec(
        'PE OUT',
        phase: PhaseTag.protectiveEarth,
        idSuffix: 'pe-out',
      ),
    ],
    visualVariant: 'ac3',
    subtitle: 'Bornier de distribution 5 conducteurs',
  ),
  F9PaletteDefinition(
    keyName: 'thermal-overload-3p',
    title: 'Relais thermique 3P',
    category: 'Triphasé',
    modelType: 'thermal_overload_3p',
    icon: Icons.device_thermostat_outlined,
    kind: F9PaletteElementKind.component,
    supportedModes: <ElectricalMode>{ElectricalMode.ac3},
    terminalLabels: <String>['1L1', '3L2', '5L3', '2T1', '4T2', '6T3'],
    terminals: <F9PaletteTerminalSpec>[
      F9PaletteTerminalSpec(
        '1L1',
        role: TerminalRole.lineL1,
        phase: PhaseTag.l1,
        idSuffix: '1l1',
      ),
      F9PaletteTerminalSpec(
        '3L2',
        role: TerminalRole.lineL2,
        phase: PhaseTag.l2,
        idSuffix: '3l2',
      ),
      F9PaletteTerminalSpec(
        '5L3',
        role: TerminalRole.lineL3,
        phase: PhaseTag.l3,
        idSuffix: '5l3',
      ),
      F9PaletteTerminalSpec(
        '2T1',
        role: TerminalRole.loadT1,
        phase: PhaseTag.l1,
        idSuffix: '2t1',
      ),
      F9PaletteTerminalSpec(
        '4T2',
        role: TerminalRole.loadT2,
        phase: PhaseTag.l2,
        idSuffix: '4t2',
      ),
      F9PaletteTerminalSpec(
        '6T3',
        role: TerminalRole.loadT3,
        phase: PhaseTag.l3,
        idSuffix: '6t3',
      ),
    ],
    defaultParameters: <String, Object?>{'ratedCurrentA': 5.0},
    defaultControlState: <String, Object?>{'closed': true, 'tripped': false},
    subtitle: 'Surcharge moteur 3φ',
  ),
];

class F9ComponentPalette extends StatefulWidget {
  const F9ComponentPalette({
    super.key,
    required this.mode,
    required this.onStatus,
    required this.onQuickAdd,
  });

  final ElectricalMode mode;
  final ValueChanged<String> onStatus;
  final ValueChanged<F9PaletteDefinition> onQuickAdd;

  @override
  State<F9ComponentPalette> createState() => _F9ComponentPaletteState();
}

class _F9ComponentPaletteState extends State<F9ComponentPalette> {
  static const int _collapsedLimit = 5;

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _category = 'Tous';
  bool _expanded = false;

  List<String> get _categories => <String>{
    'Tous',
    ...f9PaletteCatalog
        .where(
          (F9PaletteDefinition item) =>
              item.supportsMode(widget.mode) &&
              (item.kind == F9PaletteElementKind.instrument ||
                  !item.searchOnlyModes.contains(widget.mode)),
        )
        .map((F9PaletteDefinition item) => item.category),
  }.toList(growable: false);

  @override
  void didUpdateWidget(covariant F9ComponentPalette oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode == widget.mode) {
      return;
    }
    _searchController.clear();
    _query = '';
    _category = 'Tous';
    _expanded = false;
  }

  List<F9PaletteDefinition> get _filtered {
    final String q = _query.trim().toLowerCase();
    return f9PaletteCatalog
        .where((F9PaletteDefinition item) {
          if (!item.supportsMode(widget.mode)) return false;
          // Other catalog entries retain original search-only semantics.
          // Only physical instruments become available in the expanded
          // catalog and the dedicated measuring-instruments category.
          if (q.isEmpty && item.searchOnlyModes.contains(widget.mode)) {
            if (item.kind != F9PaletteElementKind.instrument ||
                (_category == 'Tous' && !_expanded)) {
              return false;
            }
          }
          final bool categoryMatches =
              _category == 'Tous' || item.category == _category;
          final bool queryMatches =
              q.isEmpty ||
              item.title.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q) ||
              item.modelType.toLowerCase().contains(q);
          return categoryMatches && queryMatches;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final List<F9PaletteDefinition> filtered = _filtered;
    final int availableCount = _query.trim().isEmpty && _category == 'Tous'
        ? f9PaletteCatalog
              .where(
                (F9PaletteDefinition item) => item.supportsMode(widget.mode),
              )
              .length
        : filtered.length;
    final bool canExpand = filtered.length > _collapsedLimit;
    final List<F9PaletteDefinition> visible = !_expanded && canExpand
        ? filtered.take(_collapsedLimit).toList(growable: false)
        : filtered;

    return ColoredBox(
      color: ElectroSimColors.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.all(ElectroSimSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextField(
              key: const Key('palette-search-field'),
              controller: _searchController,
              onChanged: (String value) => setState(() {
                _query = value;
                _expanded = true;
              }),
              decoration: InputDecoration(
                hintText: 'Rechercher un composant',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        key: const Key('palette-clear-search'),
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                            _expanded = false;
                          });
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
            const SizedBox(height: ElectroSimSpacing.sm),
            KeyedSubtree(
              key: const Key('palette-category-selector'),
              child: DropdownButtonFormField<String>(
                key: ValueKey<ElectricalMode>(widget.mode),
                initialValue: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  isDense: true,
                ),
                items: <DropdownMenuItem<String>>[
                  for (final String category in _categories)
                    DropdownMenuItem<String>(
                      value: category,
                      child: Text(
                        category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (String? category) {
                  if (category == null) {
                    return;
                  }
                  setState(() {
                    _category = category;
                    _expanded = false;
                  });
                },
              ),
            ),
            const SizedBox(height: ElectroSimSpacing.md),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('Aucun composant correspondant.'))
                  : ListView.builder(
                      key: const Key('palette-results-list'),
                      clipBehavior: Clip.hardEdge,
                      padding: const EdgeInsets.only(
                        bottom: ElectroSimSpacing.md,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (BuildContext context, int index) {
                        final F9PaletteDefinition item = visible[index];
                        return Padding(
                          padding: const EdgeInsets.only(
                            bottom: ElectroSimSpacing.sm,
                          ),
                          child: _PaletteDraggableTile(
                            definition: item,
                            onStatus: widget.onStatus,
                            onQuickAdd: widget.onQuickAdd,
                          ),
                        );
                      },
                    ),
            ),
            if (canExpand && !_expanded) ...<Widget>[
              const SizedBox(height: ElectroSimSpacing.xs),
              OutlinedButton.icon(
                key: const Key('palette-show-all'),
                onPressed: () => setState(() => _expanded = true),
                icon: const Icon(Icons.apps_outlined),
                label: const Text('Voir tous les composants'),
              ),
            ],
            const SizedBox(height: ElectroSimSpacing.xs),
            Text(
              '$availableCount composant${availableCount > 1 ? 's' : ''} '
              'disponible${availableCount > 1 ? 's' : ''} · '
              '${widget.mode.name.toUpperCase()}',
              key: const Key('palette-result-count'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: ElectroSimColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class _PaletteDraggableTile extends StatelessWidget {
  const _PaletteDraggableTile({
    required this.definition,
    required this.onStatus,
    required this.onQuickAdd,
  });

  final F9PaletteDefinition definition;
  final ValueChanged<String> onStatus;
  final ValueChanged<F9PaletteDefinition> onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final Widget tile = Material(
      color: ElectroSimColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
        side: const BorderSide(color: ElectroSimColors.workspaceDivider),
      ),
      child: InkWell(
        key: Key('palette-item-${definition.keyName}'),
        borderRadius: BorderRadius.circular(ElectroSimRadii.compact),
        onTap: () => onStatus(
          'Palette : ${definition.title} sélectionné — glissez-le sur la platine ou utilisez +.',
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ElectroSimSpacing.sm,
            vertical: ElectroSimSpacing.xs,
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                // The premium 2P body is tall; 48x56 made its controls
                // indistinguishable despite the detailed native painter.
                // Other palette entries retain their compact dimensions.
                width: definition.modelType == 'rcd_2p_ac1' ? 72 : 48,
                height: definition.modelType == 'rcd_2p_ac1' ? 108 : 56,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: F9ComponentPreview(
                    definition: definition,
                    compact: true,
                  ),
                ),
              ),
              const SizedBox(width: ElectroSimSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Tooltip(
                      message: definition.title,
                      child: Text(
                        definition.title,
                        maxLines:
                            MediaQuery.textScalerOf(context).scale(14) > 18
                            ? 2
                            : 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      definition.subtitle ?? definition.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: ElectroSimColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: Key('palette-quick-add-${definition.keyName}'),
                tooltip: 'Ajouter au centre de la platine',
                onPressed: () => onQuickAdd(definition),
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: '${definition.title}, ${definition.category}',
      hint: 'Glisser sur la platine ou utiliser le bouton ajouter',
      child: Draggable<F9PaletteDefinition>(
        data: definition,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        feedback: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: 0.94,
            // Drag uses the SAME 3/4 image as the palette. The actual board
            // is rendered frontally by F9CanvasVisualOverlay after dropping.
            child: F9ComponentPreview(definition: definition),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: tile),
        onDragStarted: () =>
            onStatus('Déplacement depuis la palette : ${definition.title}'),
        onDraggableCanceled: (_, __) =>
            onStatus('Ajout annulé : ${definition.title}'),
        child: tile,
      ),
    );
  }
}

/// Vector instrument artwork shares the front-facing form, display and
/// red/COM sockets of the physical board entity. It is not an electrical
/// component symbol and does not pass through the electrical model painter.
class F18PhysicalInstrumentPreview extends StatelessWidget {
  const F18PhysicalInstrumentPreview({
    super.key,
    required this.ammeter,
    this.compact = false,
  });

  final bool ammeter;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 72 : 112,
      height: compact ? 94 : 152,
      child: CustomPaint(
        painter: _F18PhysicalInstrumentPreviewPainter(ammeter),
      ),
    );
  }
}

final class _F18PhysicalInstrumentPreviewPainter extends CustomPainter {
  const _F18PhysicalInstrumentPreviewPainter(this.ammeter);
  final bool ammeter;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect caseRect = Offset.zero & size;
    final double radius = size.width * .105;
    canvas.drawRRect(
      RRect.fromRectAndRadius(caseRect, Radius.circular(radius)),
      Paint()..color = const Color(0xFF283748),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(caseRect, Radius.circular(radius)),
      Paint()
        ..color = const Color(0xFF101E30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final Rect display = Rect.fromLTWH(
      size.width * .10,
      size.height * .11,
      size.width * .80,
      size.height * .38,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(display, Radius.circular(size.width * .028)),
      Paint()..color = const Color(0xFFD5E5D6),
    );
    final TextPainter text = TextPainter(
      text: TextSpan(
        text: ammeter ? '— A' : '— V',
        style: TextStyle(
          fontSize: size.width * .12,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF142C1F),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: display.width);
    text.paint(
      canvas,
      Offset(
        display.center.dx - text.width / 2,
        display.center.dy - text.height / 2,
      ),
    );
    final double y = size.height * .80;
    final double socketRadius = size.width * .04;
    canvas.drawCircle(
      Offset(size.width * .28, y),
      socketRadius,
      Paint()..color = const Color(0xFFD12B3C),
    );
    canvas.drawCircle(
      Offset(size.width * .72, y),
      socketRadius,
      Paint()..color = const Color(0xFF15202D),
    );
  }

  @override
  bool shouldRepaint(covariant _F18PhysicalInstrumentPreviewPainter old) =>
      ammeter != old.ammeter;
}

class F9ComponentPreview extends StatelessWidget {
  const F9ComponentPreview({
    super.key,
    required this.definition,
    this.compact = false,
  });

  final F9PaletteDefinition definition;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Size visualSize = definition.kind == F9PaletteElementKind.instrument
        ? (compact ? const Size(72, 94) : const Size(112, 152))
        : F18ReferenceComponentVisuals.supports(definition.renderedModelType)
        ? (compact
              ? F18ReferenceComponentMetrics.paletteSizeFor(
                  definition.renderedModelType,
                )
              : F18ReferenceComponentMetrics.dragSizeFor(
                  definition.renderedModelType,
                ))
        : (compact
              ? F18ComponentIdentityMetrics.paletteSize
              : F18ComponentIdentityMetrics.dragSize);

    if (definition.modelType == 'rcd_2p_ac1') {
      // Use a dedicated high-detail preview scale. Only the display widget
      // is enlarged; neither Canvas geometry nor electrical ports change.
      final Size rcdSize = compact
          ? const Size(66, 107)
          : const Size(112, 182);
      return Disjoncteur3D(
        key: Key('component-identity-preview-${definition.keyName}'),
        width: rcdSize.width,
        height: rcdSize.height,
        vue: VueDisjoncteur.palette,
        etat: EtatDisjoncteur.ouvert,
        calibreA: 16,
        sensibiliteMA: 30,
      );
    }

    final Widget canonicalArtwork =
        definition.kind == F9PaletteElementKind.instrument
        ? F18PhysicalInstrumentPreview(
            ammeter: definition.keyName == 'instrument-ammeter',
            compact: compact,
          )
        : F18ComponentAssetVisual(
            modelType: definition.renderedModelType,
            variantKey: definition.visualVariant,
            size: visualSize,
          );

    // Every family including physical meters uses the same appearance rule.
    // Palette and drag = product perspective; board = untransformed artwork.
    return F18IndustrialDualView(
      key: Key('component-identity-preview-${definition.keyName}'),
      modelType: definition.renderedModelType,
      size: visualSize,
      presentation: F18IndustrialPresentation.palettePerspective,
      child: canonicalArtwork,
    );
  }
}
