import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'f14_library_components.dart';
import 'f18_component_archetypes.dart';
import 'reference_components/reference_models.dart';
import 'reference_components/reference_widgets.dart';
import 'reference_components/reference_widgets_extended.dart';

/// Unified reference-component contract.
///
/// The five uploaded components are rendered by the uploaded Dart painters
/// unchanged. The eight additional components use the same vector approach.
/// This adapter only maps ElectroSim runtime state to those painters.
abstract final class F18ReferenceComponentVisuals {
  static const Set<String> coveredModelTypes = <String>{
    'dc_voltage_source',
    'voltage_source',
    'switch',
    'switch_spst',
    'lamp',
    'breaker_dc',
    'breaker_ac1',
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
    'contactor_ac1',
    'contactor_3p',
    'breaker_3p',
    'thermal_overload_3p',
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

  static bool usesUploadedFive(String modelType) => switch (modelType.toLowerCase()) {
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
  static Size boardSizeFor(String modelType) => switch (modelType.toLowerCase()) {
        'dc_voltage_source' || 'voltage_source' => const Size(140, 160),
        'switch' || 'switch_spst' => const Size(90, 140),
        'lamp' => const Size(130, 160),
        'breaker_dc' || 'breaker_ac1' || 'breaker' => const Size(72, 160),
        'push_button_no' => const Size(90, 140),
        'resistor' => const Size(280, 110),
        'push_button_nc' => const Size(180, 180),
        'buzzer' => const Size(190, 190),
        'fuse_dc' || 'fuse_ac1' || 'fuse' => const Size(300, 110),
        'diode' => const Size(270, 105),
        'fan_dc' => const Size(210, 210),
        'motor_dc' => const Size(230, 190),
        'relay_coil' => const Size(190, 230),
        'capacitor' => F14LibraryGeometry.boardSizeFor(F14LibraryDevice.capacitor),
        'inductor' => F14LibraryGeometry.boardSizeFor(F14LibraryDevice.inductor),
        'impedance' => F14LibraryGeometry.boardSizeFor(F14LibraryDevice.impedance),
        'contactor_aux_no' => F14LibraryGeometry.boardSizeFor(F14LibraryDevice.auxiliaryNo),
        'contactor_aux_nc' => F14LibraryGeometry.boardSizeFor(F14LibraryDevice.auxiliaryNc),
        'contactor_ac1' => F14LibraryGeometry.boardSizeFor(F14LibraryDevice.contactorAc1),
        'contactor_3p' => F14LibraryGeometry.boardSizeFor(F14LibraryDevice.contactor3p),
        'breaker_3p' => F14LibraryGeometry.boardSizeFor(F14LibraryDevice.breaker3p),
        'thermal_overload_3p' => F14LibraryGeometry.boardSizeFor(F14LibraryDevice.thermalOverload3p),
        _ => const Size(104, 64),
      };

  static Size paletteSizeFor(String modelType) =>
      _fitInside(boardSizeFor(modelType), const Size(82, 58));

  static Size dragSizeFor(String modelType) =>
      _fitInside(boardSizeFor(modelType), const Size(160, 118));

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

  static bool hasAsset(String modelType) =>
      pathForModelType(modelType) != null;

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
    this.active = true,
    this.energized = false,
    this.closed,
    this.tripped = false,
    this.pressed = false,
    this.actuated = false,
    this.animationValue = 0,
    this.showTerminals = true,
    this.currentA = 0,
    this.voltageV = 0,
    this.ratedCurrentA = 1,
    this.currentLimitA = 2,
    this.resistanceOhm = 0,
  });

  final String modelType;
  final Size size;
  final String? variantKey;
  final bool active;
  final bool energized;
  final bool? closed;
  final bool tripped;
  final bool pressed;
  final bool actuated;
  final double animationValue;
  final bool showTerminals;
  final double currentA;
  final double voltageV;
  final double ratedCurrentA;
  final double currentLimitA;
  final double resistanceOhm;

  @override
  Widget build(BuildContext context) {
    final String type = modelType.toLowerCase();

    final ReferenceDevice? uploadedDevice =
        F18ReferenceComponentVisuals.uploadedDeviceFor(type);

    if (uploadedDevice != null) {
      final double level =
          (voltageV.abs() / 24.0).clamp(0.0, 1.0).toDouble();
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
        ),
      );
    }

    final F14LibraryDevice? libraryDevice = switch (type) {
      'capacitor' => F14LibraryDevice.capacitor,
      'inductor' => F14LibraryDevice.inductor,
      'impedance' => F14LibraryDevice.impedance,
      'contactor_aux_no' => F14LibraryDevice.auxiliaryNo,
      'contactor_aux_nc' => F14LibraryDevice.auxiliaryNc,
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
