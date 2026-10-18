import 'runtime/energy_meter_runtime.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'f18_native_appliance_visual.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'f14_library_components.dart';
import 'f15_source_pv_components.dart';
import 'f17_three_phase_components.dart';
import 'f20_catalog_components.dart';
import 'f18_power_socket_visual.dart';
import 'f18_crusher_3d_assets.dart';
import 'f18_crusher_visual.dart';
import 'f23_distribution_components.dart';
import 'f18_component_archetypes.dart';
import 'f18_control_modules_visual.dart';
import 'f18_control_device_assets.dart';
import 'f18_industrial_physical_devices.dart';
import 'f18_industrial_physical_plate.dart';
import 'reference_components/reference_models.dart';
import 'reference_components/disjoncteur_3d.dart';
import 'reference_components/reference_widgets.dart';
import 'reference_components/reference_widgets_extended.dart';

/// Unified reference-component contract.
///
/// Device-specific vector painters share their physical anchors with the
/// interactive canvas. This adapter maps existing runtime state to artwork;
/// the visual layer never advances electrical physics.
abstract final class F18ReferenceComponentVisuals {
  static const Set<String> coveredModelTypes = <String>{
    'energy_meter_ac1',
    'energy_meter_ac3',
    'power_socket_ac',
    'power_socket_dc',
    'dc_voltage_source',
    'voltage_source',
    'switch',
    'switch_spst',
    'lamp',
    'breaker_dc',
    'breaker_ac1',
    'rcd_2p_ac1',
    'breaker',
    'push_button_no',
    'resistor',
    'push_button_nc',
    'buzzer',
    'fuse_dc',
    'fuse_ac1',
    'fuse',
    'diode',
    'fan_dc',
    'motor_dc',
    'relay_coil',
    'capacitor',
    'inductor',
    'impedance',
    'contactor_aux_no',
    'contactor_aux_nc',
    'relay_contact_no',
    'relay_contact_nc',
    'contactor_ac1',
    'contactor_3p',
    'breaker_3p',
    'thermal_overload_3p',
    'dc_current_source',
    'ac_voltage_source',
    'ac_current_source',
    'ac3_voltage_source',
    'pv_array',
    'pv_controller',
    'pv_battery',
    'pv_inverter',
    'pv_resistive_load',
    'motor_3p_6t',
    'load_wye_3p',
    'load_delta_3p',
    'catalog_battery',
    'catalog_generator',
    'catalog_appliance_2t',
    'catalog_motor_driven_2t',
    'catalog_motor_driven_6t',
    'catalog_heater',
    'catalog_actuator_2t',
    'catalog_sensor_2t',
    'catalog_indicator_2t',
    'isolator_3p',
    'isolator_4p',
    'breaker_4p',
    'terminal_block_5',
    'timer_star_delta',
    'plc_ac3',
    'plc_dc',
    'mechanical_interlock_ac3',
  };

  static bool supports(String modelType) =>
      coveredModelTypes.contains(modelType.toLowerCase());

  static ReferenceDevice? uploadedDeviceFor(String modelType) =>
      switch (modelType.toLowerCase()) {
        'dc_voltage_source' || 'voltage_source' => ReferenceDevice.supply,
        'breaker_dc' || 'breaker_ac1' || 'breaker' => ReferenceDevice.breaker,
        'switch' || 'switch_spst' => ReferenceDevice.toggle,
        'push_button_no' => ReferenceDevice.button,
        'lamp' => ReferenceDevice.lamp,
        _ => null,
      };

  static bool usesUploadedFive(String modelType) =>
      switch (modelType.toLowerCase()) {
        'dc_voltage_source' ||
        'voltage_source' ||
        'switch' ||
        'switch_spst' ||
        'lamp' ||
        'breaker_dc' ||
        'breaker_ac1' ||
        'breaker' ||
        'push_button_no' => true,
        _ => false,
      };
}

abstract final class F18ReferenceComponentMetrics {
  static Size boardSizeFor(String modelType, {String? variantKey}) =>
      NativeApplianceGeometry.forVisual(modelType, variantKey)?.boardSize ??
      (modelType == 'catalog_motor_driven_6t' && variantKey == 'crusher'
          ? const Size(480, 440)
          : switch (modelType.toLowerCase()) {
              'dc_voltage_source' || 'voltage_source' => const Size(140, 160),
              'switch' || 'switch_spst' => const Size(90, 140),
              'lamp' => const Size(130, 260),
              'breaker_dc' || 'breaker_ac1' || 'breaker' => const Size(72, 160),
              'rcd_2p_ac1' => const Size(160, 260),
              'push_button_no' => const Size(90, 140),
              'resistor' => const Size(280, 110),
              'push_button_nc' => const Size(90, 140),
              'buzzer' => const Size(190, 190),
              'fuse_dc' || 'fuse_ac1' || 'fuse' => const Size(300, 110),
              'diode' => const Size(270, 105),
              'fan_dc' => const Size(210, 210),
              'motor_dc' => const Size(230, 190),
              'relay_coil' => const Size(190, 230),
              'capacitor' => F14LibraryGeometry.boardSizeFor(
                F14LibraryDevice.capacitor,
              ),
              'inductor' => F14LibraryGeometry.boardSizeFor(
                F14LibraryDevice.inductor,
              ),
              'impedance' => F14LibraryGeometry.boardSizeFor(
                F14LibraryDevice.impedance,
              ),
              'contactor_aux_no' || 'relay_contact_no' =>
                F14LibraryGeometry.boardSizeFor(F14LibraryDevice.auxiliaryNo),
              'contactor_aux_nc' || 'relay_contact_nc' =>
                F14LibraryGeometry.boardSizeFor(F14LibraryDevice.auxiliaryNc),
              'contactor_ac1' => F14LibraryGeometry.boardSizeFor(
                F14LibraryDevice.contactorAc1,
              ),
              'contactor_3p' => F14LibraryGeometry.boardSizeFor(
                F14LibraryDevice.contactor3p,
              ),
              'breaker_3p' => F14LibraryGeometry.boardSizeFor(
                F14LibraryDevice.breaker3p,
              ),
              'thermal_overload_3p' => F14LibraryGeometry.boardSizeFor(
                F14LibraryDevice.thermalOverload3p,
              ),
              'dc_current_source' => F15SourcePvGeometry.boardSizeFor(
                F15SourcePvDevice.dcCurrentSource,
              ),
              'ac_voltage_source' => F15SourcePvGeometry.boardSizeFor(
                F15SourcePvDevice.acVoltageSource,
              ),
              'ac_current_source' => F15SourcePvGeometry.boardSizeFor(
                F15SourcePvDevice.acCurrentSource,
              ),
              'ac3_voltage_source' => F15SourcePvGeometry.boardSizeFor(
                F15SourcePvDevice.ac3VoltageSource,
              ),
              'pv_array' => F15SourcePvGeometry.boardSizeFor(
                F15SourcePvDevice.pvArray,
              ),
              'pv_controller' => F15SourcePvGeometry.boardSizeFor(
                F15SourcePvDevice.pvController,
              ),
              'pv_battery' => F15SourcePvGeometry.boardSizeFor(
                F15SourcePvDevice.pvBattery,
              ),
              'pv_inverter' => F15SourcePvGeometry.boardSizeFor(
                F15SourcePvDevice.pvInverter,
              ),
              'pv_resistive_load' => F15SourcePvGeometry.boardSizeFor(
                F15SourcePvDevice.pvLoad,
              ),
              'motor_3p_6t' => F17ThreePhaseGeometry.boardSizeFor(
                F17ThreePhaseDevice.motor6t,
              ),
              'load_wye_3p' => F17ThreePhaseGeometry.boardSizeFor(
                F17ThreePhaseDevice.wyeLoad,
              ),
              'load_delta_3p' => F17ThreePhaseGeometry.boardSizeFor(
                F17ThreePhaseDevice.deltaLoad,
              ),
              'power_socket_ac' => const Size(120, 120),
              'power_socket_dc' => const Size(120, 120),
              'catalog_battery' => F20CatalogGeometry.boardSizeFor(
                F20CatalogDevice.battery,
              ),
              'catalog_generator' => F20CatalogGeometry.boardSizeFor(
                F20CatalogDevice.generator,
              ),
              'catalog_appliance_2t' => F20CatalogGeometry.boardSizeFor(
                F20CatalogDevice.appliance2t,
              ),
              'catalog_motor_driven_2t' => F20CatalogGeometry.boardSizeFor(
                F20CatalogDevice.motorDriven2t,
              ),
              'catalog_motor_driven_6t' => F20CatalogGeometry.boardSizeFor(
                F20CatalogDevice.motorDriven6t,
              ),
              'catalog_heater' => F20CatalogGeometry.boardSizeFor(
                F20CatalogDevice.heater,
              ),
              'catalog_actuator_2t' => F20CatalogGeometry.boardSizeFor(
                F20CatalogDevice.actuator2t,
              ),
              'catalog_sensor_2t' => F20CatalogGeometry.boardSizeFor(
                F20CatalogDevice.sensor2t,
              ),
              'catalog_indicator_2t' => F20CatalogGeometry.boardSizeFor(
                F20CatalogDevice.indicator2t,
              ),
              'isolator_3p' => F23DistributionGeometry.boardSizeFor(
                F23DistributionDevice.isolator3p,
              ),
              'isolator_4p' => F23DistributionGeometry.boardSizeFor(
                F23DistributionDevice.isolator4p,
              ),
              'breaker_4p' => F23DistributionGeometry.boardSizeFor(
                F23DistributionDevice.breaker4p,
              ),
              'terminal_block_5' => F23DistributionGeometry.boardSizeFor(
                F23DistributionDevice.terminalBlock5,
              ),
              'timer_star_delta' => const Size(180, 260),
              'plc_ac3' => const Size(300, 220),
              'plc_dc' => const Size(300, 220),
              'mechanical_interlock_ac3' => const Size(180, 110),
              _ => const Size(104, 64),
            });

  static Size paletteSizeFor(String modelType) => _fitInside(
    modelType.toLowerCase() == 'plc_dc'
        ? const Size(104, 64)
        : boardSizeFor(modelType),
    const Size(82, 58),
  );

  static Size dragSizeFor(String modelType) => _fitInside(
    modelType.toLowerCase() == 'plc_dc'
        ? const Size(104, 64)
        : boardSizeFor(modelType),
    const Size(160, 118),
  );

  static Size _fitInside(Size source, Size bounds) {
    final double scale = math.min(
      bounds.width / source.width,
      bounds.height / source.height,
    );
    return Size(source.width * scale, source.height * scale);
  }
}

/// Historical generated assets retained only for repository audit/history.
@Deprecated('Reference components are now rendered natively in Dart.')
abstract final class F18AdobeComponentAssets {
  static const String _root = 'assets/components/adobe';

  static const Map<String, String> _byModelType = <String, String>{
    'dc_voltage_source': '$_root/power24v.png',
    'voltage_source': '$_root/power24v.png',
    'switch': '$_root/switch.png',
    'switch_spst': '$_root/switch.png',
    'lamp': '$_root/lamp.png',
    'breaker_dc': '$_root/breaker.png',
    'breaker_ac1': '$_root/breaker.png',
    'breaker': '$_root/breaker.png',
    'push_button_no': '$_root/push_button_no.png',
  };

  static String? pathForModelType(String modelType) =>
      _byModelType[modelType.toLowerCase()];

  static bool hasAsset(String modelType) => pathForModelType(modelType) != null;

  static Set<String> get coveredModelTypes =>
      Set<String>.unmodifiable(_byModelType.keys);
}

/// Shared representation entry point used by palette, drag feedback and board.
class F18ComponentAssetVisual extends StatelessWidget {
  const F18ComponentAssetVisual({
    super.key,
    required this.modelType,
    required this.size,
    this.variantKey,
    this.powerConnectionMode = 'fixed',
    this.serviceOpen = false,
    this.meterReading,
    this.active = true,
    this.energized = false,
    this.closed,
    this.tripped = false,
    this.pressed = false,
    this.actuated = false,
    this.animationValue = 0,
    this.batterySoc = 0,
    this.showTerminals = true,
    this.currentA = 0,
    this.voltageV = 0,
    this.ratedCurrentA = 1,
    this.ratedVoltageV = 24,
    this.ratedPowerW = 10,
    this.currentLimitA = 2,
    this.resistanceOhm = 0,
    this.residualTripCurrentA = 0,
    this.controlState = const <String, Object?>{},
    this.componentParameters = const <String, Object?>{},
  });

  final String modelType;
  final Size size;
  final String? variantKey;
  final String powerConnectionMode;
  final bool serviceOpen;
  final MeterEnergyReading? meterReading;
  final bool active;
  final bool energized;
  final bool? closed;
  final bool tripped;
  final bool pressed;
  final bool actuated;
  final double animationValue;
  final double batterySoc;
  final bool showTerminals;
  final double currentA;
  final double voltageV;
  final double ratedCurrentA;
  final double ratedVoltageV;
  final double ratedPowerW;
  final double currentLimitA;
  final double resistanceOhm;
  final double residualTripCurrentA;
  final Map<String, Object?> controlState;
  final Map<String, Object?> componentParameters;

  @override
  Widget build(BuildContext context) {
    final String type = modelType.toLowerCase();
    if (type == 'mechanical_interlock_ac3') {
      final bool palette = F18PhysicalPresentationScope.perspectiveOf(context);
      final ui.Image? productImage = F18ControlDeviceAssets.image(
        'mechanical-interlock-ac3',
        palette: palette,
        activeSide: controlState['contactorAActuated'] == true
            ? 'a'
            : controlState['contactorBActuated'] == true
            ? 'b'
            : null,
      );
      if (productImage != null) {
        return RawImage(
          image: productImage,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        );
      }
      return CustomPaint(
        size: size,
        painter: _MechanicalInterlockPainter(
          perspective: F18PhysicalPresentationScope.perspectiveOf(context),
          activeSide: controlState['contactorAActuated'] == true
              ? 'a'
              : controlState['contactorBActuated'] == true
              ? 'b'
              : null,
        ),
      );
    }
    if (type == 'timer_star_delta' || type == 'plc_ac3' || type == 'plc_dc') {
      return F18ControlModuleVisual(
        modelType: type,
        size: size,
        controlState: controlState,
        parameters: componentParameters,
        active: active,
        showTerminals: showTerminals,
      );
    }
    final native = NativeApplianceGeometry.forVisual(type, variantKey);
    if (native != null) {
      return F18NativeApplianceVisual(
        spec: native,
        meterReading: meterReading,
        size: size,
        serviceOpen: serviceOpen,
        energized: energized && active,
        phase: animationValue,
      );
    }
    if (F18Crusher3dAssets.matches(type, variantKey)) {
      return F18CrusherVisual(size: size, serviceOpen: serviceOpen);
    }
    if (type == 'power_socket_ac' || type == 'power_socket_dc') {
      return F18PowerSocketVisual(size: size, dc: type == 'power_socket_dc');
    }
    if (F18PhysicalPlateAssets.ready(type, variantKey: variantKey)) {
      return F18IndustrialPhysicalPlate(
        modelType: type,
        size: size,
        perspective: F18PhysicalPresentationScope.perspectiveOf(context),
        closed: closed ?? true,
        tripped: tripped,
        pressed: pressed,
        energized: energized,
        actuated: actuated,
        active: active,
        showTerminals: showTerminals,
        phase: animationValue,
        currentA: currentA,
        voltageV: voltageV,
        ratedCurrentA: ratedCurrentA,
        currentLimitA: currentLimitA,
        resistanceOhm: resistanceOhm,
        batterySoc: batterySoc,
        variantKey: variantKey,
      );
    }
    if (type == 'rcd_2p_ac1') {
      // Genuine 3D painter, directly in frontal camera on the physical board.
      // Unlike the 1P breaker, this device really has four canonical ports.
      return Disjoncteur3D(
        width: size.width,
        height: size.height,
        vue: VueDisjoncteur.platine,
        etat: tripped
            ? EtatDisjoncteur.declenche
            : closed == false
            ? EtatDisjoncteur.ouvert
            : EtatDisjoncteur.ferme,
        calibreA: ratedCurrentA > 0 ? ratedCurrentA : null,
        sensibiliteMA: residualTripCurrentA > 0
            ? residualTripCurrentA * 1000
            : null,
        afficherBornes: showTerminals,
        // Canvas owns hit-testing and invokes the single model controller.
        onCommande: null,
        onTest: null,
        onBorne: null,
      );
    }

    // Genuine replacement industrial drawings. Never wrap the old drawing
    // and call it a replacement: these eight are new canonical silhouettes
    // with preserved design-space ports for the existing G12RQ hit-testing.
    final IndustrialDevice? physical = IndustrialDeviceContract.resolve(type);
    if (physical != null) {
      return IndustrialPhysicalView(
        device: physical,
        size: size,
        closed: closed ?? true,
        tripped: tripped,
        pressed: pressed,
        energized: energized,
        animationValue: animationValue,
        showTerminals: showTerminals,
        currentA: physical == IndustrialDevice.supply
            ? (energized ? currentA.abs() : 0)
            : currentA,
        voltageV: active ? voltageV.abs() : 0,
        ratedCurrentA: ratedCurrentA,
        domain: type == 'breaker_ac1' ? 'AC' : 'CC',
        supplyMode: !active
            ? SupplyMode.off
            : !energized
            ? SupplyMode.constantVoltage
            : currentA.abs() >= currentLimitA * .98
            ? SupplyMode.constantCurrent
            : SupplyMode.constantVoltage,
      );
    }

    final ReferenceDevice? uploadedDevice =
        F18ReferenceComponentVisuals.uploadedDeviceFor(type);

    if (uploadedDevice != null) {
      final double level = (voltageV.abs() / 24.0).clamp(0.0, 1.0).toDouble();
      final double brightness = energized ? level * level : 0;
      final double temperatureK = 293.15 + brightness * (2700 - 293.15);
      final SupplyMode supplyMode = !active
          ? SupplyMode.off
          : (!energized
                ? SupplyMode.constantVoltage
                : (currentA.abs() >= currentLimitA * .98
                      ? SupplyMode.constantCurrent
                      : SupplyMode.constantVoltage));

      return ReferenceComponentView(
        device: uploadedDevice,
        width: size.width,
        height: size.height,
        showTerminals: showTerminals,
        state: ReferenceVisualState(
          closed: closed ?? true,
          pressed: pressed,
          tripped: tripped,
          brightness: brightness,
          temperatureK: temperatureK,
          voltageV: active ? voltageV.abs() : 0,
          currentA: uploadedDevice == ReferenceDevice.supply
              ? (energized ? currentA.abs() : 0)
              : (active ? currentA.abs() : 0),
          supplyMode: supplyMode,
          ratedCurrentA: ratedCurrentA,
          ratedVoltageV: ratedVoltageV,
          ratedPowerW: ratedPowerW,
          protectionDomainLabel: type == 'breaker_ac1' ? 'AC' : 'CC',
        ),
      );
    }

    final ExtendedReferenceDevice? extendedDevice = switch (type) {
      'resistor' => ExtendedReferenceDevice.resistor,
      'push_button_nc' => ExtendedReferenceDevice.pushButtonNc,
      'buzzer' => ExtendedReferenceDevice.buzzer,
      'fuse_dc' || 'fuse_ac1' || 'fuse' => ExtendedReferenceDevice.fuse,
      'diode' => ExtendedReferenceDevice.diode,
      'fan_dc' => ExtendedReferenceDevice.fan,
      'motor_dc' => ExtendedReferenceDevice.motor,
      'relay_coil' => ExtendedReferenceDevice.relayCoil,
      _ => null,
    };

    if (extendedDevice != null) {
      final double speedFraction = energized
          ? (voltageV.abs() / 24.0).clamp(0.0, 1.0).toDouble()
          : 0;
      final double motorDirection = currentA < 0 ? -1 : 1;
      return ExtendedReferenceComponentView(
        device: extendedDevice,
        width: size.width,
        height: size.height,
        showTerminals: showTerminals,
        state: ExtendedReferenceVisualState(
          pressed: pressed,
          active: energized,
          blown: tripped,
          forwardBiased: currentA > 1e-6,
          speedFraction: speedFraction,
          speedRpm: speedFraction * 3000 * motorDirection,
          energized: energized,
          currentA: currentA,
          voltageV: voltageV,
          resistanceOhm: resistanceOhm,
          animationValue: animationValue,
          variantKey: variantKey,
        ),
      );
    }

    final F14LibraryDevice? libraryDevice = switch (type) {
      'capacitor' => F14LibraryDevice.capacitor,
      'inductor' => F14LibraryDevice.inductor,
      'impedance' => F14LibraryDevice.impedance,
      'contactor_aux_no' || 'relay_contact_no' => F14LibraryDevice.auxiliaryNo,
      'contactor_aux_nc' || 'relay_contact_nc' => F14LibraryDevice.auxiliaryNc,
      'contactor_ac1' => F14LibraryDevice.contactorAc1,
      'contactor_3p' => F14LibraryDevice.contactor3p,
      'breaker_3p' => F14LibraryDevice.breaker3p,
      'thermal_overload_3p' => F14LibraryDevice.thermalOverload3p,
      _ => null,
    };
    if (libraryDevice != null) {
      return F14LibraryComponentView(
        device: libraryDevice,
        size: size,
        state: F14LibraryVisualState(
          active: active,
          energized: energized,
          closed: closed ?? true,
          tripped: tripped,
          actuated: actuated,
          currentA: currentA,
          voltageV: voltageV,
          variantKey: variantKey,
        ),
      );
    }

    final F15SourcePvDevice? sourcePvDevice = switch (type) {
      'dc_current_source' => F15SourcePvDevice.dcCurrentSource,
      'ac_voltage_source' => F15SourcePvDevice.acVoltageSource,
      'ac_current_source' => F15SourcePvDevice.acCurrentSource,
      'ac3_voltage_source' => F15SourcePvDevice.ac3VoltageSource,
      'pv_array' => F15SourcePvDevice.pvArray,
      'pv_controller' => F15SourcePvDevice.pvController,
      'pv_battery' => F15SourcePvDevice.pvBattery,
      'pv_inverter' => F15SourcePvDevice.pvInverter,
      'pv_resistive_load' => F15SourcePvDevice.pvLoad,
      _ => null,
    };
    if (sourcePvDevice != null) {
      return F15SourcePvComponentView(
        device: sourcePvDevice,
        size: size,
        state: F15SourcePvState(
          active: active,
          energized: energized,
          currentA: currentA,
          voltageV: voltageV,
          animationValue: animationValue,
          batterySoc: batterySoc,
          variantKey: variantKey,
        ),
      );
    }

    final F17ThreePhaseDevice? threePhaseDevice = switch (type) {
      'motor_3p_6t' => F17ThreePhaseDevice.motor6t,
      'load_wye_3p' => F17ThreePhaseDevice.wyeLoad,
      'load_delta_3p' => F17ThreePhaseDevice.deltaLoad,
      _ => null,
    };
    if (threePhaseDevice != null) {
      return F17ThreePhaseComponentView(
        device: threePhaseDevice,
        size: size,
        state: F17ThreePhaseState(
          energized: energized,
          currentA: currentA,
          voltageV: voltageV,
          animationValue: animationValue,
        ),
      );
    }

    final F23DistributionDevice? distributionDevice = switch (type) {
      'isolator_3p' => F23DistributionDevice.isolator3p,
      'isolator_4p' => F23DistributionDevice.isolator4p,
      'breaker_4p' => F23DistributionDevice.breaker4p,
      'terminal_block_5' => F23DistributionDevice.terminalBlock5,
      _ => null,
    };
    if (distributionDevice != null) {
      return F23DistributionComponentView(
        device: distributionDevice,
        size: size,
        state: F23DistributionState(
          closed: closed ?? true,
          tripped: tripped,
          energized: energized,
          currentA: currentA,
          variantKey: variantKey,
        ),
      );
    }

    final F20CatalogDevice? catalogDevice = switch (type) {
      'catalog_battery' => F20CatalogDevice.battery,
      'catalog_generator' => F20CatalogDevice.generator,
      'catalog_appliance_2t' => F20CatalogDevice.appliance2t,
      'catalog_motor_driven_2t' => F20CatalogDevice.motorDriven2t,
      'catalog_motor_driven_6t' => F20CatalogDevice.motorDriven6t,
      'catalog_heater' => F20CatalogDevice.heater,
      'catalog_actuator_2t' => F20CatalogDevice.actuator2t,
      'catalog_sensor_2t' => F20CatalogDevice.sensor2t,
      'catalog_indicator_2t' => F20CatalogDevice.indicator2t,
      _ => null,
    };
    if (catalogDevice != null) {
      final bool sensorContactActuated =
          type == 'limit_switch_nc' ? closed == false : closed == true;
      return F20CatalogComponentView(
        device: catalogDevice,
        size: size,
        state: F20CatalogState(
          powerConnectionMode: powerConnectionMode,
          energized: energized,
          actuated:
              actuated ||
              (catalogDevice == F20CatalogDevice.sensor2t &&
                  sensorContactActuated),
          currentA: currentA,
          voltageV: voltageV,
          animationValue: animationValue,
          variantKey: variantKey,
        ),
      );
    }

    return F18ComponentIdentityVisual(
      modelType: modelType,
      size: size,
      active: active,
    );
  }
}

/// Rendered mechanical bridge used to prevent both reversing contactors from
/// closing together. The palette adds shallow depth; the plate keeps a square
/// frontal view so the hardware reads clearly at component scale.
final class _MechanicalInterlockPainter extends CustomPainter {
  const _MechanicalInterlockPainter({required this.perspective, this.activeSide});

  final bool perspective;
  final String? activeSide;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / 200, size.height / 120);

    final Path body = Path()
      ..moveTo(24, 24)
      ..lineTo(176, 24)
      ..lineTo(188, 35)
      ..lineTo(188, 86)
      ..lineTo(176, 96)
      ..lineTo(24, 96)
      ..lineTo(12, 86)
      ..lineTo(12, 35)
      ..close();
    canvas.drawShadow(body, const Color(0x99000000), 6, true);

    if (perspective) {
      final Path rightWall = Path()
        ..moveTo(188, 35)
        ..lineTo(197, 28)
        ..lineTo(197, 78)
        ..lineTo(188, 86)
        ..close();
      canvas.drawPath(
        rightWall,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF68747B), Color(0xFF3C474D)],
          ).createShader(const Rect.fromLTWH(188, 28, 9, 58)),
      );
      final Path topWall = Path()
        ..moveTo(24, 24)
        ..lineTo(34, 17)
        ..lineTo(197, 20)
        ..lineTo(188, 27)
        ..close();
      canvas.drawPath(
        topWall,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFF7F8F5), Color(0xFF9EA8AD)],
          ).createShader(const Rect.fromLTWH(24, 17, 173, 10)),
      );
    }

    canvas.drawPath(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF5F6F3),
            Color(0xFFC9D0D2),
            Color(0xFF87939A),
          ],
          stops: [0, .52, 1],
        ).createShader(const Rect.fromLTWH(12, 24, 176, 72)),
    );
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF566168)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );

    // Mounting ears and captive fasteners at both contactor ends.
    for (final double x in [4, 196]) {
      final Rect ear = Rect.fromCenter(
        center: Offset(x, 60),
        width: 12,
        height: 42,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(ear, const Radius.circular(3)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFE8ECEB), Color(0xFF66737A)],
          ).createShader(ear),
      );
      canvas.drawCircle(
        Offset(x, 60),
        3.7,
        Paint()..color = const Color(0xFF3D484E),
      );
      canvas.drawCircle(
        Offset(x, 60),
        2.2,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFF9FAF8), Color(0xFF79858B)],
          ).createShader(Rect.fromCircle(center: Offset(x, 60), radius: 2.2)),
      );
      canvas.drawLine(
        Offset(x - 1.4, 60),
        Offset(x + 1.4, 60),
        Paint()
          ..color = const Color(0xFF404A50)
          ..strokeWidth = .7,
      );
    }

    // The central sliding bridge locks one contactor arm while the other is
    // pulled in. Layered rails give the mechanism a molded, machined profile.
    final RRect track = RRect.fromRectAndRadius(
      const Rect.fromLTWH(37, 43, 126, 36),
      const Radius.circular(8),
    );
    canvas.drawRRect(track, Paint()..color = const Color(0xFF414D53));
    canvas.drawRRect(
      track.deflate(3),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF758187), Color(0xFF29343A)],
        ).createShader(const Rect.fromLTWH(40, 46, 120, 30)),
    );
    final double sliderShift = activeSide == 'a'
        ? -28
        : activeSide == 'b'
        ? 28
        : 0;
    final RRect slider = RRect.fromRectAndRadius(
      Rect.fromLTWH(75 + sliderShift, 48, 50, 26),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      slider,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD15A), Color(0xFFD38B16), Color(0xFF855515)],
        ).createShader(slider.outerRect),
    );
    canvas.drawRRect(
      slider,
      Paint()
        ..color = const Color(0xFF714D1B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      Offset(100 + sliderShift, 51),
      Offset(100 + sliderShift, 71),
      Paint()
        ..color = const Color(0xFF5E441F)
        ..strokeWidth = 2,
    );

    // Small safety marking and embossed device designation.
    final Path warning = Path()
      ..moveTo(100, 29)
      ..lineTo(111, 39)
      ..lineTo(89, 39)
      ..close();
    canvas.drawPath(warning, Paint()..color = const Color(0xFFE6AA23));
    canvas.drawLine(
      const Offset(100, 32),
      const Offset(100, 36),
      Paint()
        ..color = const Color(0xFF4A3A1B)
        ..strokeWidth = 1.3,
    );
    canvas.drawCircle(
      const Offset(100, 37.5),
      .8,
      Paint()..color = const Color(0xFF4A3A1B),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_MechanicalInterlockPainter oldDelegate) =>
      oldDelegate.perspective != perspective ||
      oldDelegate.activeSide != activeSide;
}
