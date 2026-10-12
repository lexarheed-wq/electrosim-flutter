import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'f18_voltmeter_controls.dart';

abstract final class F18FrequencyControls {
  static bool held(InstrumentInstance m) =>
      m.settings['g5_frequency_hold'] == true;
  static bool lit(InstrumentInstance m) =>
      m.settings['g5_frequency_light'] == true;
  static F18VoltmeterAction? actionAt(Offset p, Size size) {
    if (size.width <= 0 || size.height <= 0) return null;
    final x = p.dx * 112 / size.width, y = p.dy * 152 / size.height;
    if (y < 71 || y > 85) return null;
    if (x >= 27 && x <= 43) return F18VoltmeterAction.hold;
    if (x >= 48 && x <= 64) return F18VoltmeterAction.selector;
    if (x >= 69 && x <= 85) return F18VoltmeterAction.light;
    return null;
  }

  static InstrumentInstance apply(
    InstrumentInstance m,
    F18VoltmeterAction action, {
    String? text,
    double? value,
    bool valid = false,
  }) {
    if (m.kind != InstrumentKind.frequencyMeter) return m;
    final settings = <String, Object?>{...m.settings};
    var powered = m.poweredOn;
    switch (action) {
      case F18VoltmeterAction.selector:
        powered = !powered;
        settings.remove('g5_frequency_hold');
        settings.remove('g5_frequency_text');
      case F18VoltmeterAction.light:
        settings['g5_frequency_light'] = !lit(m);
      case F18VoltmeterAction.hold:
        if (held(m)) {
          settings.remove('g5_frequency_hold');
          settings.remove('g5_frequency_text');
        } else {
          if (!m.poweredOn ||
              !valid ||
              text == null ||
              value == null ||
              !value.isFinite) {
            return m;
          }
          settings['g5_frequency_hold'] = true;
          settings['g5_frequency_text'] = text;
        }
      default:
        return m;
    }
    return InstrumentInstance.fromJson({
      ...m.toJson(),
      'poweredOn': powered,
      'settings': settings,
    });
  }

  static String display(InstrumentInstance m, String computed, bool valid) =>
      m.poweredOn && valid && held(m)
      ? (m.settings['g5_frequency_text'] as String? ?? computed)
      : computed;
}
