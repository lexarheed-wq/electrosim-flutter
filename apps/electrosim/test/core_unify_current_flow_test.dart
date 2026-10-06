import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:electrosim/runtime/electrosim_runtime_engine.dart';

void main() {
  test('DC wire flow follows solved current, not stored drawing direction', () {
    final Connection positiveWire = Connection(
      id: ConnectionId('positive-wire'),
      // Deliberately stored opposite to conventional current direction.
      fromTerminalId: TerminalId('ra'),
      toTerminalId: TerminalId('vp'),
    );
    final Connection negativeWire = Connection(
      id: ConnectionId('negative-wire'),
      fromTerminalId: TerminalId('rb'),
      toTerminalId: TerminalId('vn'),
    );
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('core-unify-flow'),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[
            Terminal(id: TerminalId('vp'), name: '+'),
            Terminal(id: TerminalId('vn'), name: '−'),
          ],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('r1'),
          modelType: 'resistor',
          terminals: <Terminal>[
            Terminal(id: TerminalId('ra'), name: 'A'),
            Terminal(id: TerminalId('rb'), name: 'B'),
          ],
          parameters: const <String, Object?>{
            ComponentParameterKeys.resistanceOhm: 24.0,
          },
        ),
      ],
      connections: <Connection>[positiveWire, negativeWire],
    );

    const ElectroSimRuntimeEngine engine = ElectroSimRuntimeEngine();
    final ElectroSimRuntimeSnapshot snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue);

    final ConnectionCurrentEvidence positive = snapshot
        .connectionCurrentEvidence(positiveWire);
    final ConnectionCurrentEvidence negative = snapshot
        .connectionCurrentEvidence(negativeWire);

    expect(positive.directionKnown, isTrue);
    expect(positive.signedCurrentA, closeTo(-1.0, 1e-9));
    expect(negative.directionKnown, isTrue);
    expect(negative.signedCurrentA, closeTo(1.0, 1e-9));
  });
}
