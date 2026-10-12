import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'f18_voltmeter_controls.dart';

/// Component 02: controls a FUSED serial ammeter; never bypasses burden.
abstract final class F18AmmeterControls {
  static const holdKey = 'g5_ammeter_hold';
  static const heldTextKey = 'g5_ammeter_held_text';
  static const lightKey = 'g5_ammeter_light';
  static const rangeKey = 'g5_ammeter_range';
  static const limits = <double>[0.2, 2.0, 10.0];

  static bool held(InstrumentInstance i) => i.settings[holdKey] == true;
  static bool lit(InstrumentInstance i) => i.settings[lightKey] == true;
  static int rangeIndex(InstrumentInstance i) {
    final raw = i.settings[rangeKey];
    return raw is int && raw >= 0 && raw <= limits.length ? raw : 0;
  }

  static String rangeLabel(InstrumentInstance i) {
    final index = rangeIndex(i);
    if (index == 0) return 'AUTO';
    final amperes = limits[index - 1];
    return amperes < 1
        ? '${(amperes * 1000).toInt()} mA'
        : '${amperes.toStringAsFixed(amperes == 10 ? 0 : 1)} A';
  }

  static String display(
    InstrumentInstance i,
    String text,
    double? measured,
    bool valid,
  ) {
    if (i.fuseBlown) return 'FUSE';
    if (!i.poweredOn) return 'OFF';
    if (held(i)) return (i.settings[heldTextKey] as String?) ?? 'ERR';
    if (!valid || measured == null || !measured.isFinite) return text;
    final index = rangeIndex(i);
    return index > 0 && measured.abs() > limits[index - 1] ? 'OL' : text;
  }

  /// Current-meter selector is above its fuse cover (centre y=86, not
  /// the voltmeter's y=91). The fuse hatch y=110..118 remains non-interactive
  /// until an explicit, safe physical replacement workflow is implemented.
  static F18VoltmeterAction? actionAt(Offset location, Size extent) {
    if (extent.width <= 0 || extent.height <= 0) return null;
    final x = location.dx * 112 / extent.width;
    final y = location.dy * 152 / extent.height;
    if (y >= 50 && y <= 65) {
      if (x >= 28 && x < 42) return F18VoltmeterAction.hold;
      if (x >= 42 && x < 56) return F18VoltmeterAction.range;
      if (x >= 56 && x < 70) return F18VoltmeterAction.select;
      if (x >= 70 && x <= 84) return F18VoltmeterAction.light;
    }
    final dx = x - 53.0;
    final dy = y - 86.0;
    if (dx * dx + dy * dy <= 20 * 20) {
      return F18VoltmeterAction.selector;
    }
    return null;
  }

  static InstrumentInstance apply(
    InstrumentInstance meter,
    F18VoltmeterAction action, {
    String? text,
    double? value,
    bool valid = false,
  }) {
    if (meter.kind != InstrumentKind.ammeter) return meter;
    final state = <String, Object?>{...meter.settings};
    var mode = meter.mode;
    var powered = meter.poweredOn;
    switch (action) {
      case F18VoltmeterAction.hold:
        if (held(meter)) {
          state.remove(holdKey);
          state.remove(heldTextKey);
        } else {
          if (!valid || text == null || value == null || !value.isFinite) {
            return meter;
          }
          state[holdKey] = true;
          state[heldTextKey] = text;
        }
      case F18VoltmeterAction.range:
        if (!powered) return meter;
        state[rangeKey] = (rangeIndex(meter) + 1) % 4;
      case F18VoltmeterAction.select:
        if (!powered) return meter;
        mode = mode == InstrumentMode.currentAcRms
            ? InstrumentMode.currentDc
            : InstrumentMode.currentAcRms;
        state.remove(holdKey);
        state.remove(heldTextKey);
      case F18VoltmeterAction.light:
        state[lightKey] = !lit(meter);
      case F18VoltmeterAction.selector:
        if (!powered) {
          powered = true;
          mode = InstrumentMode.currentDc;
        } else if (mode == InstrumentMode.currentDc) {
          mode = InstrumentMode.currentAcRms;
        } else {
          powered = false;
          mode = InstrumentMode.currentDc;
        }
        state.remove(holdKey);
        state.remove(heldTextKey);
        state[rangeKey] = 0;
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
      poweredOn: powered,
      cutConnectionId: meter.cutConnectionId,
      settings: state,
    );
  }
}
