import 'package:electrosim/f18_voltmeter_controls.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  InstrumentInstance meter({bool poweredOn = true}) => InstrumentInstance(
    id: InstrumentId('g5-meter'),
    kind: InstrumentKind.voltmeter,
    mode: InstrumentMode.voltageDc,
    poweredOn: poweredOn,
  );

  test('physical hit targets match four labelled buttons and selector', () {
    const size = Size(112, 152);
    for (final (x, action) in <(double, F18VoltmeterAction)>[
      (35, F18VoltmeterAction.hold),
      (49, F18VoltmeterAction.range),
      (63, F18VoltmeterAction.select),
      (77, F18VoltmeterAction.light),
    ]) {
      expect(F18VoltmeterControls.actionAt(Offset(x, 56), size), action);
    }
    expect(F18VoltmeterControls.actionAt(const Offset(53, 91), size),
      F18VoltmeterAction.selector);
    expect(F18VoltmeterControls.actionAt(const Offset(17, 17), size), isNull);
    expect(F18VoltmeterControls.actionAt(const Offset(70, 112), size), isNull);
    // Same exact hit logic regardless of visual zoom.
    expect(F18VoltmeterControls.actionAt(const Offset(154, 112),
      const Size(224, 304)), F18VoltmeterAction.light);
  });

  test('HOLD freezes only real readings and releases correctly', () {
    final original = meter();
    expect(identical(F18VoltmeterControls.apply(
      meter: original, action: F18VoltmeterAction.hold,
      currentReading: 'ERR', validReading: false,
    ), original), isTrue);
    final held = F18VoltmeterControls.apply(
      meter: original, action: F18VoltmeterAction.hold,
      currentReading: '24.00 V', currentValue: 24, validReading: true,
    );
    expect(F18VoltmeterControls.isHeld(held), isTrue);
    expect(F18VoltmeterControls.display(
      meter: held, computedText: '0.00 V',
      computedValue: 0, validReading: true,
    ), '24.00 V');
    expect(F18VoltmeterControls.display(
      meter: held, computedText: 'ERR', validReading: false,
    ), '24.00 V');
    final released = F18VoltmeterControls.apply(
      meter: held, action: F18VoltmeterAction.hold,
    );
    expect(F18VoltmeterControls.isHeld(released), isFalse);
    expect(F18VoltmeterControls.display(
      meter: released, computedText: 'ERR', validReading: false,
    ), 'ERR');
  });

  test('RANGE is automatic / 20 / 200 / 600 V with genuine overrange', () {
    var m = meter();
    expect(F18VoltmeterControls.rangeLabel(m), 'AUTO');
    m = F18VoltmeterControls.apply(
      meter: m, action: F18VoltmeterAction.range);
    expect(F18VoltmeterControls.rangeLabel(m), '20 V');
    expect(F18VoltmeterControls.display(
      meter: m, computedText: '24.00 V',
      computedValue: 24, validReading: true,
    ), 'OL');
    expect(F18VoltmeterControls.display(
      meter: m, computedText: 'ERR', validReading: false,
    ), 'ERR');
    m = F18VoltmeterControls.apply(
      meter: m, action: F18VoltmeterAction.range);
    expect(F18VoltmeterControls.rangeLabel(m), '200 V');
    expect(F18VoltmeterControls.display(
      meter: m, computedText: '24.00 V',
      computedValue: 24, validReading: true,
    ), '24.00 V');
    m = F18VoltmeterControls.apply(
      meter: m, action: F18VoltmeterAction.range);
    expect(F18VoltmeterControls.rangeLabel(m), '600 V');
    m = F18VoltmeterControls.apply(
      meter: m, action: F18VoltmeterAction.range);
    expect(F18VoltmeterControls.rangeLabel(m), 'AUTO');
  });

  test('SELECT changes DC/AC; LIGHT is independent of the solver', () {
    final a = meter();
    final lit = F18VoltmeterControls.apply(
      meter: a, action: F18VoltmeterAction.light);
    expect(F18VoltmeterControls.isLit(lit), isTrue);
    expect(lit.mode, InstrumentMode.voltageDc);
    final ac = F18VoltmeterControls.apply(
      meter: lit, action: F18VoltmeterAction.select);
    expect(ac.mode, InstrumentMode.voltageAcRms);
    expect(ac.settings[F18VoltmeterControls.lightKey], true);
    final dc = F18VoltmeterControls.apply(
      meter: ac, action: F18VoltmeterAction.select);
    expect(dc.mode, InstrumentMode.voltageDc);
    expect(F18VoltmeterControls.isLit(dc), isTrue);
  });

  test('selector visits DC, AC, resistance and OFF', () {
    final m = meter(poweredOn: false);
    final dc = F18VoltmeterControls.apply(
      meter: m, action: F18VoltmeterAction.selector);
    expect(dc.poweredOn, isTrue);
    expect(dc.mode, InstrumentMode.voltageDc);
    final ac = F18VoltmeterControls.apply(
      meter: dc, action: F18VoltmeterAction.selector);
    expect(ac.mode, InstrumentMode.voltageAcRms);
    final ohm = F18VoltmeterControls.apply(
      meter: ac, action: F18VoltmeterAction.selector);
    expect(ohm.mode, InstrumentMode.resistance);
    expect(identical(F18VoltmeterControls.apply(
      meter: ohm, action: F18VoltmeterAction.range,
    ), ohm), isTrue);
    final off = F18VoltmeterControls.apply(
      meter: ohm, action: F18VoltmeterAction.selector);
    expect(off.poweredOn, isFalse);
    expect(F18VoltmeterControls.display(
      meter: off, computedText: '24.00 V',
      computedValue: 24, validReading: true,
    ), 'OFF');
  });

  test('instrument state does not insert power wires or probe leads', () {
    final base = buildRegressionFixtureCircuit();
    final m = meter();
    final circuit = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      sources: base.sources,
      components: base.components,
      connections: base.connections,
      instruments: [m],
      probes: [
        ProbeConnection(
          id: ProbeId('probe-v'),
          instrumentId: m.id,
          port: InstrumentPort.voltOhm,
          terminalId: TerminalId('lamp-in'),
        ),
        ProbeConnection(
          id: ProbeId('probe-com'),
          instrumentId: m.id,
          port: InstrumentPort.common,
          terminalId: TerminalId('lamp-out'),
        ),
      ],
    );
    final updatedMeter = F18VoltmeterControls.apply(
      meter: m, action: F18VoltmeterAction.light);
    expect(updatedMeter.id, m.id);
    expect(updatedMeter.kind, m.kind);
    expect(updatedMeter.inputImpedanceOhm, m.inputImpedanceOhm);
    expect(circuit.connections, hasLength(3));
    expect(circuit.probes, hasLength(2));
    expect(updatedMeter.settings[F18VoltmeterControls.lightKey], true);
  });
}
