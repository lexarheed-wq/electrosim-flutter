import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:electrosim/f9_component_visuals.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';

void main() {
  test('dash phase follows signed conventional current', () {
    final double forwardEarly = f9CurrentFlowDashPhase(
      elapsedSeconds: 0.05,
      speed: 20,
    );
    final double forwardLater = f9CurrentFlowDashPhase(
      elapsedSeconds: 0.10,
      speed: 20,
    );
    final double reverseEarly = f9CurrentFlowDashPhase(
      elapsedSeconds: 0.05,
      speed: -20,
    );
    final double reverseLater = f9CurrentFlowDashPhase(
      elapsedSeconds: 0.10,
      speed: -20,
    );

    expect(forwardLater, greaterThan(forwardEarly));
    expect(reverseLater, lessThan(reverseEarly));
  });

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
  test('energized open circuit keeps potential but has no current-flow animation', () {
    final Terminal vp = Terminal(
      id: TerminalId('open-vp'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal vn = Terminal(
      id: TerminalId('open-vn'),
      name: '−',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );
    final Terminal sa = Terminal(id: TerminalId('open-sa'), name: 'A');
    final Terminal sb = Terminal(id: TerminalId('open-sb'), name: 'B');
    final Terminal ra = Terminal(id: TerminalId('open-ra'), name: 'A');
    final Terminal rb = Terminal(id: TerminalId('open-rb'), name: 'B');
    final Connection positiveWire = Connection(
      id: ConnectionId('open-p'),
      fromTerminalId: vp.id,
      toTerminalId: sa.id,
      phase: PhaseTag.dcPositive,
    );
    final Connection loadWire = Connection(
      id: ConnectionId('open-load'),
      fromTerminalId: sb.id,
      toTerminalId: ra.id,
    );
    final Connection negativeWire = Connection(
      id: ConnectionId('open-n'),
      fromTerminalId: rb.id,
      toTerminalId: vn.id,
      phase: PhaseTag.dcNegative,
    );
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('open-potential-no-flow'),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('open-source'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[vp, vn],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('open-switch'),
          modelType: 'switch',
          terminals: <Terminal>[sa, sb],
          controlState: const <String, Object?>{'closed': false},
        ),
        ComponentInstance(
          id: ComponentId('open-resistor'),
          modelType: 'resistor',
          terminals: <Terminal>[ra, rb],
          parameters: const <String, Object?>{
            ComponentParameterKeys.resistanceOhm: 24.0,
          },
        ),
      ],
      connections: <Connection>[positiveWire, loadWire, negativeWire],
    );

    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);
    expect(snapshot.solved, isTrue);
    final String positiveNode =
        snapshot.topology.terminalToNode[vp.id]!;
    final String negativeNode =
        snapshot.topology.terminalToNode[vn.id]!;
    expect(
      (snapshot.dc.nodeVoltages[positiveNode]! -
              snapshot.dc.nodeVoltages[negativeNode]!)
          .abs(),
      closeTo(24.0, 1e-9),
    );

    for (final Connection connection in circuit.connections) {
      final ConnectionCurrentEvidence flow =
          snapshot.connectionCurrentEvidence(connection);
      expect(flow.magnitudeA, closeTo(0.0, 1e-12));
      expect(f9ShouldPaintCurrentFlow(flow), isFalse);
    }
  });


}
