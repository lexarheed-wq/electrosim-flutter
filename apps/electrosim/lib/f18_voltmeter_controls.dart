import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';

/// Controls are UI state, never ordinary circuit connections.
enum F18VoltmeterAction { hold, range, select, light, selector }

abstract final class F18VoltmeterControls {
  static const String holdKey = 'g5_voltmeter_hold';
  static const String heldTextKey = 'g5_voltmeter_held_text';
  static const String heldValueKey = 'g5_voltmeter_held_value';
  static const String rangeIndexKey = 'g5_voltmeter_range_index';
  static const String lightKey = 'g5_voltmeter_light';
  static const List<double> voltageRanges = <double>[20, 200, 600];

  static bool isHeld(InstrumentInstance meter) => meter.settings[holdKey] == true;
  static bool isLit(InstrumentInstance meter) => meter.settings[lightKey] == true;
  static int rangeIndex(InstrumentInstance meter) {
    final value = meter.settings[rangeIndexKey];
    if (value is int && value >= 0 && value <= voltageRanges.length) return value;
    return 0;
  }

  static String rangeLabel(InstrumentInstance meter) {
    final index = rangeIndex(meter);
    return index == 0 ? 'AUTO' : '${voltageRanges[index - 1].toInt()} V';
  }

  /// Logical action positions match Blender's 112x152 instrument contract.
  static F18VoltmeterAction? actionAt(Offset point, Size extent) {
    if (extent.width <= 0 || extent.height <= 0) return null;
    final x = point.dx * 112 / extent.width;
    final y = point.dy * 152 / extent.height;
    if (y >= 50 && y <= 65) {
      if (x >= 28 && x < 42) return F18VoltmeterAction.hold;
      if (x >= 42 && x < 56) return F18VoltmeterAction.range;
      if (x >= 56 && x < 70) return F18VoltmeterAction.select;
      if (x >= 70 && x <= 84) return F18VoltmeterAction.light;
    }
    final dx = x - 53;
    final dy = y - 91;
    if (dx * dx + dy * dy <= 24 * 24) return F18VoltmeterAction.selector;
    return null;
  }

  static InstrumentInstance apply({
    required InstrumentInstance meter,
    required F18VoltmeterAction action,
    String? currentReading,
    double? currentValue,
    bool validReading = false,
  }) {
    if (meter.kind != InstrumentKind.voltmeter) return meter;
    final settings = <String, Object?>{...meter.settings};
    var mode = meter.mode;
    var poweredOn = meter.poweredOn;
    switch (action) {
      case F18VoltmeterAction.hold:
        if (isHeld(meter)) {
          settings.remove(holdKey);
          settings.remove(heldTextKey);
          settings.remove(heldValueKey);
        } else {
          if (!validReading || currentReading == null ||
              currentValue == null || !currentValue.isFinite) return meter;
          settings[holdKey] = true;
          settings[heldTextKey] = currentReading;
          settings[heldValueKey] = currentValue;
        }
      case F18VoltmeterAction.range:
        if (!poweredOn || mode == InstrumentMode.resistance) return meter;
        settings[rangeIndexKey] =
            (rangeIndex(meter) + 1) % (voltageRanges.length + 1);
      case F18VoltmeterAction.select:
        if (!poweredOn || mode == InstrumentMode.resistance) return meter;
        mode = mode == InstrumentMode.voltageAcRms
            ? InstrumentMode.voltageDc : InstrumentMode.voltageAcRms;
        settings.remove(holdKey);
        settings.remove(heldTextKey);
        settings.remove(heldValueKey);
      case F18VoltmeterAction.light:
        settings[lightKey] = !isLit(meter);
      case F18VoltmeterAction.selector:
        if (!poweredOn) {
          poweredOn = true;
          mode = InstrumentMode.voltageDc;
        } else if (mode == InstrumentMode.voltageDc) {
          mode = InstrumentMode.voltageAcRms;
        } else if (mode == InstrumentMode.voltageAcRms) {
          mode = InstrumentMode.resistance;
        } else {
          poweredOn = false;
          mode = InstrumentMode.voltageDc;
        }
        settings.remove(holdKey);
        settings.remove(heldTextKey);
        settings.remove(heldValueKey);
        settings[rangeIndexKey] = 0;
    }
    return InstrumentInstance(
      id: meter.id,
      kind: meter.kind,
      mode: mode,
      inputImpedanceOhm: meter.inputImpedanceOhm,
      burdenResistanceOhm: meter.burdenResistanceOhm,
      maximumVoltageV: meter.maximumVoltageV,
      maximumCurrentA: meter.maximumCurrentA,
      fuseRatingA: meter.fuseRatingA,
      fuseBlown: meter.fuseBlown,
      poweredOn: poweredOn,
      cutConnectionId: meter.cutConnectionId,
      settings: settings,
    );
  }

  /// A HOLD never freezes ERR/OFF/unconnected data as a real reading.
  static String display({
    required InstrumentInstance meter,
    required String computedText,
    double? computedValue,
    required bool validReading,
  }) {
    if (!meter.poweredOn) return 'OFF';
    if (isHeld(meter)) {
      final held = meter.settings[heldTextKey];
      return held is String && held.isNotEmpty ? held : 'ERR';
    }
    if (!validReading || computedValue == null || !computedValue.isFinite) {
      return computedText;
    }
    if (meter.mode == InstrumentMode.resistance) return computedText;
    final index = rangeIndex(meter);
    return index != 0 && computedValue.abs() > voltageRanges[index - 1]
        ? 'OL' : computedText;
  }
}
