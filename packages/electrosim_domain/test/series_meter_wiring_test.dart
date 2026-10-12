import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

void main() {
  CircuitState setup({
    String? amp = 'a',
    String? common = 'b',
    bool enabled = true,
    bool powered = true,
    bool blown = false,
    bool cut = true,
    InstrumentKind kind = InstrumentKind.ammeter,
  }) {
    final meter = InstrumentInstance(
      id: InstrumentId('meter'),
      kind: kind,
      mode: InstrumentMode.currentDc,
      poweredOn: powered,
      fuseBlown: blown,
      cutConnectionId: cut ? ConnectionId('wire') : null,
    );
    return CircuitState(
      circuitId: CircuitId('series'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: [
        ComponentInstance(
          id: ComponentId('load'),
          modelType: 'resistor',
          terminals: [
            for (final id in ['a', 'b', 'c'])
              Terminal(id: TerminalId(id), name: id),
          ],
        ),
      ],
      connections: [
        Connection(
          id: ConnectionId('wire'),
          fromTerminalId: TerminalId('a'),
          toTerminalId: TerminalId('b'),
          enabled: enabled,
        ),
      ],
      instruments: [meter],
      probes: [
        if (amp != null)
          ProbeConnection(
            id: ProbeId('a-lead'),
            instrumentId: meter.id,
            port: InstrumentPort.amp,
            terminalId: TerminalId(amp),
          ),
        if (common != null)
          ProbeConnection(
            id: ProbeId('com-lead'),
            instrumentId: meter.id,
            port: InstrumentPort.common,
            terminalId: TerminalId(common),
          ),
      ],
    );
  }

  for (final reverse in [false, true]) {
    for (final powered in [false, true]) {
      test(
        'physical series cut survives polarity $reverse and power $powered',
        () {
          final circuit = setup(
            amp: reverse ? 'b' : 'a',
            common: reverse ? 'a' : 'b',
            powered: powered,
          );
          expect(
            SeriesMeterWiring.wiredCut(circuit, circuit.instruments.single),
            same(circuit.connections.single),
          );
          expect(SeriesMeterWiring.openConnectionIds(circuit), {
            ConnectionId('wire'),
          });
          expect(circuit.connections.single.enabled, isTrue);
        },
      );
    }
  }
  for (final pair in [(null, 'b'), ('a', null), ('a', 'a'), ('a', 'c')]) {
    test(
      'incomplete or nonbridging leads $pair leave permanent wire intact',
      () {
        final circuit = setup(amp: pair.$1, common: pair.$2);
        expect(
          SeriesMeterWiring.wiredCut(circuit, circuit.instruments.single),
          isNull,
        );
        expect(SeriesMeterWiring.openConnectionIds(circuit), isEmpty);
      },
    );
  }
  test('disabled wire is never a usable cut', () {
    final circuit = setup(enabled: false);
    expect(
      SeriesMeterWiring.wiredCut(circuit, circuit.instruments.single),
      isNull,
    );
    expect(SeriesMeterWiring.openConnectionIds(circuit), isEmpty);
  });
  test('blown fuse keeps cut open even with detached leads and power off', () {
    final circuit = setup(amp: null, common: null, blown: true, powered: false);
    expect(
      SeriesMeterWiring.wiredCut(circuit, circuit.instruments.single),
      isNull,
    );
    expect(SeriesMeterWiring.openConnectionIds(circuit), {
      ConnectionId('wire'),
    });
  });
  test(
    'other instrument kinds and meters without a cut never open the wire',
    () {
      for (final circuit in [
        setup(kind: InstrumentKind.voltmeter, blown: true),
        setup(cut: false, blown: true),
      ]) {
        expect(
          SeriesMeterWiring.wiredCut(circuit, circuit.instruments.single),
          isNull,
        );
        expect(SeriesMeterWiring.openConnectionIds(circuit), isEmpty);
      }
    },
  );
}
