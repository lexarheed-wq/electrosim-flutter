import 'package:electrosim/f18_frequency_controls.dart';
import 'package:electrosim/f18_frequency_3d_assets.dart';
import 'package:electrosim/f18_voltmeter_controls.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  InstrumentInstance meter() => InstrumentInstance(
    id: InstrumentId('F'),
    kind: InstrumentKind.frequencyMeter,
    mode: InstrumentMode.frequency,
    settings: const {'custom': 'keep'},
    inputImpedanceOhm: 2000000,
  );
  test('frequency display fits its dedicated large LCD', () {
    final lcd = F18Frequency3dAssets.projectReadout(
      const Rect.fromLTWH(0, 0, 112, 152),
    );
    expect(lcd, const Rect.fromLTWH(28, 26, 56, 24));
  });
  test('OFF and ON keep frequency mode, identity and input impedance', () {
    final original = meter();
    final off = F18FrequencyControls.apply(
      original,
      F18VoltmeterAction.selector,
    );
    expect(off.poweredOn, isFalse);
    final on = F18FrequencyControls.apply(off, F18VoltmeterAction.selector);
    expect(on.toJson(), original.toJson());
    expect(on.mode, InstrumentMode.frequency);
  });
  test('HOLD refuses missing readings and releases an existing reading', () {
    final original = meter();
    expect(
      identical(
        F18FrequencyControls.apply(original, F18VoltmeterAction.hold),
        original,
      ),
      isTrue,
    );
    final held = F18FrequencyControls.apply(
      original,
      F18VoltmeterAction.hold,
      text: '60.00 Hz',
      value: 60,
      valid: true,
    );
    expect(F18FrequencyControls.display(held, '50.00 Hz', true), '60.00 Hz');
    expect(F18FrequencyControls.display(held, 'ERR', false), 'ERR');
    final released = F18FrequencyControls.apply(held, F18VoltmeterAction.hold);
    expect(
      F18FrequencyControls.display(released, '50.00 Hz', true),
      '50.00 Hz',
    );
    expect(released.settings['custom'], 'keep');
  });
  test('front control hit zones avoid LCD and probe sockets at any size', () {
    expect(
      F18FrequencyControls.actionAt(const Offset(35, 78), const Size(112, 152)),
      F18VoltmeterAction.hold,
    );
    expect(
      F18FrequencyControls.actionAt(
        const Offset(112, 156),
        const Size(224, 304),
      ),
      F18VoltmeterAction.selector,
    );
    expect(
      F18FrequencyControls.actionAt(const Offset(77, 78), const Size(112, 152)),
      F18VoltmeterAction.light,
    );
    expect(
      F18FrequencyControls.actionAt(
        const Offset(42, 128),
        const Size(112, 152),
      ),
      isNull,
    );
    expect(
      F18FrequencyControls.actionAt(const Offset(56, 38), const Size(112, 152)),
      isNull,
    );
  });
}
