import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'physical_families_instruments_dynamics_qualification_test.dart'
    as fixture;

void main() {
  InstrumentInstance meter({bool on = true}) => InstrumentInstance(
    id: InstrumentId('phase-meter'),
    kind: InstrumentKind.phaseSequenceTester,
    mode: InstrumentMode.phaseSequence,
    poweredOn: on,
  );
  PhysicalInstrumentReading read(
    List<String> picks, {
    bool on = true,
    ElectricalMode mode = ElectricalMode.ac3,
  }) {
    final m = meter(on: on);
    final circuit = fixture.withInstrument(fixture.acCircuit(mode: mode), m, [
      for (var i = 0; i < picks.length; i++)
        fixture.probe(
          'p$i',
          m,
          [
            InstrumentPort.phase1,
            InstrumentPort.phase2,
            InstrumentPort.phase3,
          ][i],
          picks[i],
        ),
    ]);
    return fixture.projector.read(
      snapshot: fixture.engine.evaluate(circuit),
      instrument: m,
    );
  }

  test('all six physical probe permutations retain the correct rotation', () {
    for (final picks in [
      ['l1', 'l2', 'l3'],
      ['l2', 'l3', 'l1'],
      ['l3', 'l1', 'l2'],
    ]) {
      final r = read(picks);
      expect(r.status, PhysicalInstrumentStatus.valid);
      expect(r.result?.displayText, 'L1 → L2 → L3');
    }
    for (final picks in [
      ['l1', 'l3', 'l2'],
      ['l3', 'l2', 'l1'],
      ['l2', 'l1', 'l3'],
    ]) {
      final r = read(picks);
      expect(r.status, PhysicalInstrumentStatus.valid);
      expect(r.result?.displayText, 'L1 → L3 → L2');
    }
  });
  test(
    'missing, duplicate and neutral probes never report a valid rotation',
    () {
      for (final picks in [
        ['l1', 'l2'],
        ['l1', 'l1', 'l2'],
        ['l1', 'l2', 'n'],
      ]) {
        final r = read(picks);
        expect(
          r.status,
          isNot(PhysicalInstrumentStatus.valid),
          reason: picks.toString(),
        );
        expect(r.result?.displayText, isNull);
      }
    },
  );
  test('unknown terminal is rejected by the circuit identity contract', () {
    expect(
      () => read(['l1', 'l2', 'missing']),
      throwsA(isA<DomainException>()),
    );
  });
  test('single phase and powered-off tester do not fabricate a rotation', () {
    expect(
      read(['l1', 'n', 'r1-a'], mode: ElectricalMode.ac1).status,
      isNot(PhysicalInstrumentStatus.valid),
    );
    expect(
      read(['l1', 'l2', 'l3'], on: false).status,
      isNot(PhysicalInstrumentStatus.valid),
    );
  });
}
