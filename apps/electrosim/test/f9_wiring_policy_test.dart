import 'package:electrosim/f9_wiring_policy.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'accepts compatible generic-to-phase wiring and appends a connection',
    () {
      final CircuitState circuit = _circuit();
      final F9WiringDecision decision = F9WiringPolicy.evaluateAndBuild(
        circuit,
        TerminalId('source-pos'),
        TerminalId('switch-in'),
      );
      expect(decision.accepted, isTrue);
      expect(decision.connection, isNotNull);
      expect(decision.connection!.id.value, 'wire-1');
      expect(decision.connection!.phase, PhaseTag.dcPositive);

      final CircuitState next = F9WiringPolicy.append(
        circuit,
        decision.connection!,
      );
      expect(next.revision, circuit.revision + 1);
      expect(next.connections.length, 1);
    },
  );

  test('rejects incompatible explicit phases', () {
    final CircuitState circuit = _circuit();
    final F9WiringDecision decision = F9WiringPolicy.evaluateAndBuild(
      circuit,
      TerminalId('source-pos'),
      TerminalId('load-neg'),
    );
    expect(decision.accepted, isFalse);
    expect(decision.message, contains('incompatible'));
  });

  test('rejects duplicate reverse connection', () {
    final CircuitState base = _circuit();
    final Connection existing = Connection(
      id: ConnectionId('wire-1'),
      fromTerminalId: TerminalId('source-pos'),
      toTerminalId: TerminalId('switch-in'),
      phase: PhaseTag.dcPositive,
    );
    final CircuitState circuit = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      components: base.components,
      sources: base.sources,
      connections: <Connection>[existing],
    );
    final F9WiringDecision decision = F9WiringPolicy.evaluateAndBuild(
      circuit,
      TerminalId('switch-in'),
      TerminalId('source-pos'),
    );
    expect(decision.accepted, isFalse);
    expect(decision.message, contains('déjà reliées'));
  });
}

CircuitState _circuit() {
  return CircuitState(
    circuitId: CircuitId('wiring-policy'),
    revision: 1,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('source'),
        modelType: 'DC 24 V',
        terminals: <Terminal>[
          Terminal(
            id: TerminalId('source-pos'),
            name: '+',
            role: TerminalRole.positive,
            phase: PhaseTag.dcPositive,
          ),
          Terminal(
            id: TerminalId('source-neg'),
            name: '−',
            role: TerminalRole.negative,
            phase: PhaseTag.dcNegative,
          ),
        ],
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('switch'),
        modelType: 'Interrupteur',
        terminals: <Terminal>[
          Terminal(
            id: TerminalId('switch-in'),
            name: '1',
            role: TerminalRole.input,
          ),
          Terminal(
            id: TerminalId('switch-out'),
            name: '2',
            role: TerminalRole.output,
          ),
        ],
      ),
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'Charge polarisée',
        terminals: <Terminal>[
          Terminal(
            id: TerminalId('load-pos'),
            name: '+',
            role: TerminalRole.positive,
            phase: PhaseTag.dcPositive,
          ),
          Terminal(
            id: TerminalId('load-neg'),
            name: '−',
            role: TerminalRole.negative,
            phase: PhaseTag.dcNegative,
          ),
        ],
      ),
    ],
  );
}
