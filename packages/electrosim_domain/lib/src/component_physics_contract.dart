import 'component.dart';
import 'component_model_contract.dart';
import 'electrical_ratings.dart';

/// Canonical electrical law consumed by solver/runtime layers.
///
/// Model names stay at the registry boundary. Downstream engines should reason
/// from these semantics instead of scattering `modelType == ...` checks.
enum ComponentElectricalLaw {
  resistive,
  capacitor,
  inductor,
  diode,
  binarySwitch,
  protectionSwitch,
  feedThrough,
  acImpedance,
  motorThreePhase,
  loadWyeThreePhase,
  loadDeltaThreePhase,
  converter,
  storage,
  unsupported,
}

/// Canonical control semantics for binary/electromechanical devices.
enum ComponentControlLaw {
  none,
  maintainedSwitch,
  momentaryNormallyOpen,
  momentaryNormallyClosed,
  relayNormallyOpen,
  relayNormallyClosed,
  electromagneticCoil,
  protection,
}

/// Runtime phenomena that may persist across solver steps.
enum ComponentDynamicBehavior {
  thermalStress,
  rotational,
  electromagnetic,
  protectiveTrip,
}

/// One source of truth for physical parameter names shared by UI, runtime and
/// solvers. New physical keys must be added here before use elsewhere.
abstract final class ComponentParameterKeys {
  static const String resistanceOhm = 'resistanceOhm';
  static const String reactanceOhm = 'reactanceOhm';
  static const String capacitanceF = 'capacitanceF';
  static const String inductanceH = 'inductanceH';
  static const String forwardVoltageV = 'forwardVoltageV';
  static const String offResistanceOhm = 'offResistanceOhm';
  static const String reverseBreakdownVoltageV = 'reverseBreakdownVoltageV';
  static const String maxVoltageV = 'maxVoltageV';
  static const String maxCurrentA = 'maxCurrentA';
  static const String maxPowerW = 'maxPowerW';
  static const String thermalWithstandSeconds = 'thermalWithstandSeconds';
  static const String coilPickupVoltageV = 'coilPickupVoltageV';
  static const String coilDropoutVoltageV = 'coilDropoutVoltageV';
}

/// Canonical physics semantics for one component model.
final class ComponentPhysicsContract {
  const ComponentPhysicsContract({
    required this.modelType,
    required this.electricalLaw,
    this.controlLaw = ComponentControlLaw.none,
    this.dynamicBehaviors = const <ComponentDynamicBehavior>{},
  });

  final String modelType;
  final ComponentElectricalLaw electricalLaw;
  final ComponentControlLaw controlLaw;
  final Set<ComponentDynamicBehavior> dynamicBehaviors;

  bool get isSwitching =>
      controlLaw != ComponentControlLaw.none &&
      controlLaw != ComponentControlLaw.electromagneticCoil;

  bool get canAccumulateThermalStress =>
      dynamicBehaviors.contains(ComponentDynamicBehavior.thermalStress);
}

/// Immutable central physics registry.
///
/// This is intentionally the only place where canonical model names are
/// translated into electrical/control semantics. Engines consume the resulting
/// contract rather than duplicating model-name switches.
abstract final class CoreComponentPhysicsContracts {
  static final Map<String, ComponentPhysicsContract> _byModelType =
      Map<String, ComponentPhysicsContract>.unmodifiable(
        <String, ComponentPhysicsContract>{
          'resistor': const ComponentPhysicsContract(
            modelType: 'resistor',
            electricalLaw: ComponentElectricalLaw.resistive,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
            },
          ),
          'lamp': const ComponentPhysicsContract(
            modelType: 'lamp',
            electricalLaw: ComponentElectricalLaw.resistive,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
            },
          ),
          'buzzer': const ComponentPhysicsContract(
            modelType: 'buzzer',
            electricalLaw: ComponentElectricalLaw.resistive,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
            },
          ),
          'fan_dc': const ComponentPhysicsContract(
            modelType: 'fan_dc',
            electricalLaw: ComponentElectricalLaw.resistive,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
              ComponentDynamicBehavior.rotational,
            },
          ),
          'motor_dc': const ComponentPhysicsContract(
            modelType: 'motor_dc',
            electricalLaw: ComponentElectricalLaw.resistive,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
              ComponentDynamicBehavior.rotational,
            },
          ),
          'relay_coil': const ComponentPhysicsContract(
            modelType: 'relay_coil',
            electricalLaw: ComponentElectricalLaw.resistive,
            controlLaw: ComponentControlLaw.electromagneticCoil,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
              ComponentDynamicBehavior.electromagnetic,
            },
          ),
          'capacitor': const ComponentPhysicsContract(
            modelType: 'capacitor',
            electricalLaw: ComponentElectricalLaw.capacitor,
          ),
          'inductor': const ComponentPhysicsContract(
            modelType: 'inductor',
            electricalLaw: ComponentElectricalLaw.inductor,
          ),
          'diode': const ComponentPhysicsContract(
            modelType: 'diode',
            electricalLaw: ComponentElectricalLaw.diode,
          ),
          'impedance': const ComponentPhysicsContract(
            modelType: 'impedance',
            electricalLaw: ComponentElectricalLaw.acImpedance,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
            },
          ),
          'switch': const ComponentPhysicsContract(
            modelType: 'switch',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.maintainedSwitch,
          ),
          'switch_spst': const ComponentPhysicsContract(
            modelType: 'switch_spst',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.maintainedSwitch,
          ),
          'push_button_no': const ComponentPhysicsContract(
            modelType: 'push_button_no',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.momentaryNormallyOpen,
          ),
          'push_button_nc': const ComponentPhysicsContract(
            modelType: 'push_button_nc',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.momentaryNormallyClosed,
          ),
          'relay_contact_no': const ComponentPhysicsContract(
            modelType: 'relay_contact_no',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.relayNormallyOpen,
          ),
          'relay_contact_nc': const ComponentPhysicsContract(
            modelType: 'relay_contact_nc',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.relayNormallyClosed,
          ),
          'contactor_aux_no': const ComponentPhysicsContract(
            modelType: 'contactor_aux_no',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.relayNormallyOpen,
          ),
          'contactor_aux_nc': const ComponentPhysicsContract(
            modelType: 'contactor_aux_nc',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.relayNormallyClosed,
          ),
          'breaker_dc': const ComponentPhysicsContract(
            modelType: 'breaker_dc',
            electricalLaw: ComponentElectricalLaw.protectionSwitch,
            controlLaw: ComponentControlLaw.protection,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.protectiveTrip,
            },
          ),
          'fuse_dc': const ComponentPhysicsContract(
            modelType: 'fuse_dc',
            electricalLaw: ComponentElectricalLaw.protectionSwitch,
            controlLaw: ComponentControlLaw.protection,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.protectiveTrip,
            },
          ),
          'breaker_ac1': const ComponentPhysicsContract(
            modelType: 'breaker_ac1',
            electricalLaw: ComponentElectricalLaw.protectionSwitch,
            controlLaw: ComponentControlLaw.protection,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.protectiveTrip,
            },
          ),
          'fuse_ac1': const ComponentPhysicsContract(
            modelType: 'fuse_ac1',
            electricalLaw: ComponentElectricalLaw.protectionSwitch,
            controlLaw: ComponentControlLaw.protection,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.protectiveTrip,
            },
          ),
          'terminal_block_5': const ComponentPhysicsContract(
            modelType: 'terminal_block_5',
            electricalLaw: ComponentElectricalLaw.feedThrough,
          ),
          'motor_3p_6t': const ComponentPhysicsContract(
            modelType: 'motor_3p_6t',
            electricalLaw: ComponentElectricalLaw.motorThreePhase,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
              ComponentDynamicBehavior.rotational,
            },
          ),
          'load_wye_3p': const ComponentPhysicsContract(
            modelType: 'load_wye_3p',
            electricalLaw: ComponentElectricalLaw.loadWyeThreePhase,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
            },
          ),
          'load_delta_3p': const ComponentPhysicsContract(
            modelType: 'load_delta_3p',
            electricalLaw: ComponentElectricalLaw.loadDeltaThreePhase,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
            },
          ),
          'breaker_3p': const ComponentPhysicsContract(
            modelType: 'breaker_3p',
            electricalLaw: ComponentElectricalLaw.protectionSwitch,
            controlLaw: ComponentControlLaw.protection,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.protectiveTrip,
            },
          ),
          'breaker_4p': const ComponentPhysicsContract(
            modelType: 'breaker_4p',
            electricalLaw: ComponentElectricalLaw.protectionSwitch,
            controlLaw: ComponentControlLaw.protection,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.protectiveTrip,
            },
          ),
          'thermal_overload_3p': const ComponentPhysicsContract(
            modelType: 'thermal_overload_3p',
            electricalLaw: ComponentElectricalLaw.protectionSwitch,
            controlLaw: ComponentControlLaw.protection,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.protectiveTrip,
            },
          ),
          'isolator_3p': const ComponentPhysicsContract(
            modelType: 'isolator_3p',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.maintainedSwitch,
          ),
          'isolator_4p': const ComponentPhysicsContract(
            modelType: 'isolator_4p',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.maintainedSwitch,
          ),
          'contactor_ac1': const ComponentPhysicsContract(
            modelType: 'contactor_ac1',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.electromagneticCoil,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.electromagnetic,
            },
          ),
          'contactor_3p': const ComponentPhysicsContract(
            modelType: 'contactor_3p',
            electricalLaw: ComponentElectricalLaw.binarySwitch,
            controlLaw: ComponentControlLaw.electromagneticCoil,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.electromagnetic,
            },
          ),
          'pv_controller': const ComponentPhysicsContract(
            modelType: 'pv_controller',
            electricalLaw: ComponentElectricalLaw.converter,
          ),
          'pv_inverter': const ComponentPhysicsContract(
            modelType: 'pv_inverter',
            electricalLaw: ComponentElectricalLaw.converter,
          ),
          'pv_battery': const ComponentPhysicsContract(
            modelType: 'pv_battery',
            electricalLaw: ComponentElectricalLaw.storage,
          ),
          'pv_resistive_load': const ComponentPhysicsContract(
            modelType: 'pv_resistive_load',
            electricalLaw: ComponentElectricalLaw.resistive,
            dynamicBehaviors: <ComponentDynamicBehavior>{
              ComponentDynamicBehavior.thermalStress,
            },
          ),
        },
      );

  static ComponentPhysicsContract? resolve(String modelType) =>
      _byModelType[modelType];

  static ComponentPhysicsContract resolveComponent(ComponentInstance component) =>
      resolve(component.modelType) ??
      ComponentPhysicsContract(
        modelType: component.modelType,
        electricalLaw: ComponentElectricalLaw.unsupported,
      );

  static Iterable<ComponentPhysicsContract> get contracts =>
      _byModelType.values;

  /// Verifies that every canonical structural model also has one physics
  /// contract. This is used by architecture tests/guards.
  static Set<String> missingPhysicsContracts() => <String>{
    for (final ComponentModelContract contract
        in CoreComponentModelContracts.registry.contracts)
      if (!_byModelType.containsKey(contract.modelType)) contract.modelType,
  };
}

/// Generic operating envelope shared by runtime state, UI warnings and tests.
final class ComponentOperatingEnvelope {
  const ComponentOperatingEnvelope({
    this.nominalVoltageV,
    this.nominalCurrentA,
    this.nominalPowerW,
    this.maxVoltageV,
    this.maxCurrentA,
    this.maxPowerW,
    this.thermalWithstandSeconds,
  });

  final double? nominalVoltageV;
  final double? nominalCurrentA;
  final double? nominalPowerW;
  final double? maxVoltageV;
  final double? maxCurrentA;
  final double? maxPowerW;
  final double? thermalWithstandSeconds;

  factory ComponentOperatingEnvelope.fromComponent(ComponentInstance component) {
    final ReceiverNominalRating? nominal =
        ReceiverNominalRating.tryFromParameters(component.parameters);
    return ComponentOperatingEnvelope(
      nominalVoltageV: nominal?.voltageV,
      nominalCurrentA: nominal?.currentA,
      nominalPowerW: nominal?.powerW,
      maxVoltageV: _positive(component.parameters[ComponentParameterKeys.maxVoltageV]),
      maxCurrentA: _positive(component.parameters[ComponentParameterKeys.maxCurrentA]),
      maxPowerW: _positive(component.parameters[ComponentParameterKeys.maxPowerW]),
      thermalWithstandSeconds: _positive(
        component.parameters[ComponentParameterKeys.thermalWithstandSeconds],
      ),
    );
  }

  double? get effectiveMaxVoltageV =>
      maxVoltageV ?? _scaled(nominalVoltageV, 1.10);
  double? get effectiveMaxCurrentA =>
      maxCurrentA ?? _scaled(nominalCurrentA, 1.25);
  double? get effectiveMaxPowerW => maxPowerW ?? _scaled(nominalPowerW, 1.25);

  static double? _scaled(double? value, double factor) =>
      value == null ? null : value * factor;
}

double? _positive(Object? raw) {
  if (raw is! num) return null;
  final double value = raw.toDouble();
  return value.isFinite && value > 0 ? value : null;
}
