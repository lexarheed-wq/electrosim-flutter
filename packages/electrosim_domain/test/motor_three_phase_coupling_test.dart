import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

void main() {
  ComponentInstance motor() => ComponentInstance(
    id: ComponentId('m1'),
    modelType: 'motor_3p_6t',
    terminals: <Terminal>[
      _t('u1'), _t('v1'), _t('w1'), _t('u2'), _t('v2'), _t('w2'),
    ],
    parameters: const <String, Object?>{
      'resistanceOhm': 18.0,
      'inductanceH': 0.035,
    },
  );

  CircuitState circuit(ComponentInstance m, List<Connection> wires) =>
      CircuitState(
        circuitId: CircuitId('motor-coupling'),
        revision: 0,
        mode: ElectricalMode.ac3,
        components: <ComponentInstance>[m],
        connections: wires,
      );

  test('detects complete external star coupling', () {
    final ComponentInstance m = motor();
    final result = MotorThreePhaseCouplingEvaluator.evaluate(
      circuit(m, <Connection>[
        _w('s1', 'u2', 'v2'),
        _w('s2', 'v2', 'w2'),
      ]),
      m,
    );
    expect(result.kind, MotorThreePhaseCouplingKind.star);
    expect(result.isValid, isTrue);
  });

  test('detects both valid external delta orientations', () {
    for (final List<Connection> wires in <List<Connection>>[
      <Connection>[
        _w('d1', 'u2', 'v1'),
        _w('d2', 'v2', 'w1'),
        _w('d3', 'w2', 'u1'),
      ],
      <Connection>[
        _w('d1', 'u2', 'w1'),
        _w('d2', 'v2', 'u1'),
        _w('d3', 'w2', 'v1'),
      ],
    ]) {
      final ComponentInstance m = motor();
      final result = MotorThreePhaseCouplingEvaluator.evaluate(
        circuit(m, wires),
        m,
      );
      expect(result.kind, MotorThreePhaseCouplingKind.delta);
      expect(result.isValid, isTrue);
    }
  });

  test('rejects partial star coupling from physical validation case', () {
    final ComponentInstance m = motor();
    final result = MotorThreePhaseCouplingEvaluator.evaluate(
      circuit(m, <Connection>[_w('partial', 'u2', 'v2')]),
      m,
    );
    expect(result.kind, MotorThreePhaseCouplingKind.incomplete);
    expect(result.isValid, isFalse);
  });

  test('rejects malformed delta-like coupling', () {
    final ComponentInstance m = motor();
    final result = MotorThreePhaseCouplingEvaluator.evaluate(
      circuit(m, <Connection>[
        _w('bad1', 'u1', 'v2'),
        _w('bad2', 'v1', 'u2'),
      ]),
      m,
    );
    expect(result.isValid, isFalse);
  });
}

Terminal _t(String id) => Terminal(id: TerminalId(id), name: id.toUpperCase());

Connection _w(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);
