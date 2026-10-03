
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ElectroSimRuntimeEngine runtime = ElectroSimRuntimeEngine();

  test('runtime evaluate applies magnetic DC trip at zero simulated time', () {
    final CircuitState circuit = _dcBreakerCircuit();
    final ElectroSimRuntimeSnapshot snapshot = runtime.evaluate(circuit);

    expect(snapshot.solved, isTrue);
    expect(snapshot.protectionTripped(ComponentId('q1')), isTrue);
    expect(snapshot.protectionIssues, isEmpty);
    expect(
      snapshot.dc.branch('component:r1').currentA,
      closeTo(0.0, 1e-12),
    );
  });

  test('runtime advance carries AC3 thermal exposure across simulated time',
      () {
    final CircuitState circuit = _ac3ThermalCircuit();

    final ElectroSimRuntimeSnapshot first = runtime.advance(
      circuit,
      elapsed: const Duration(seconds: 60),
    );
    expect(first.solved, isTrue);
    expect(first.protectionTripped(ComponentId('rt1')), isFalse);
    expect(
      first.protectionState![ComponentId('rt1')]!.exposure.exposure,
      closeTo(0.5, 1e-7),
    );

    final ElectroSimRuntimeSnapshot second = runtime.advance(
      circuit,
      elapsed: const Duration(seconds: 60),
      previousProtectionState: first.protectionState,
    );
    expect(second.solved, isTrue);
    expect(second.protectionTripped(ComponentId('rt1')), isTrue);
    for (final String id in <String>['r1', 'r2', 'r3']) {
      expect(
        second.ac3.branch('component:$id').current!.magnitude,
        closeTo(0.0, 1e-12),
      );
    }
  });
}

CircuitState _dcBreakerCircuit() => CircuitState(
      circuitId: CircuitId('runtime-protection-dc'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('q1'),
          modelType: 'breaker_dc',
          terminals: <Terminal>[_t('q-in', 'IN'), _t('q-out', 'OUT')],
          parameters: <String, Object?>{
            ProtectionRating.ratedCurrentKey: 2.0,
            'tripCurve': 'C',
          },
          controlState: const <String, Object?>{
            'closed': true,
            'tripped': false,
          },
        ),
        ComponentInstance(
          id: ComponentId('r1'),
          modelType: 'resistor',
          terminals: <Terminal>[_t('r-in', 'A'), _t('r-out', 'B')],
          parameters: const <String, Object?>{'resistanceOhm': 0.1},
        ),
      ],
      connections: <Connection>[
        _wire('w1', 'vp', 'q-in'),
        _wire('w2', 'q-out', 'r-in'),
        _wire('w3', 'r-out', 'vn'),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[
            _t('vp', '+', phase: PhaseTag.dcPositive),
            _t('vn', '−', phase: PhaseTag.dcNegative),
          ],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
    );

CircuitState _ac3ThermalCircuit() => CircuitState(
      circuitId: CircuitId('runtime-protection-ac3'),
      revision: 0,
      mode: ElectricalMode.ac3,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('rt1'),
          modelType: 'thermal_overload_3p',
          terminals: <Terminal>[
            _t('rt-l1-in', '1L1', phase: PhaseTag.l1),
            _t('rt-l2-in', '3L2', phase: PhaseTag.l2),
            _t('rt-l3-in', '5L3', phase: PhaseTag.l3),
            _t('rt-l1-out', '2T1', phase: PhaseTag.l1),
            _t('rt-l2-out', '4T2', phase: PhaseTag.l2),
            _t('rt-l3-out', '6T3', phase: PhaseTag.l3),
          ],
          parameters: <String, Object?>{
            ProtectionRating.ratedCurrentKey: 5.0,
          },
          controlState: const <String, Object?>{
            'closed': true,
            'tripped': false,
          },
        ),
        _load('r1', PhaseTag.l1),
        _load('r2', PhaseTag.l2),
        _load('r3', PhaseTag.l3),
      ],
      connections: <Connection>[
        _wire('p1', 'v1-p', 'rt-l1-in'),
        _wire('p2', 'v2-p', 'rt-l2-in'),
        _wire('p3', 'v3-p', 'rt-l3-in'),
        _wire('o1', 'rt-l1-out', 'r1-p'),
        _wire('o2', 'rt-l2-out', 'r2-p'),
        _wire('o3', 'rt-l3-out', 'r3-p'),
        _wire('n1', 'r1-n', 'v1-n'),
        _wire('n2', 'r2-n', 'v1-n'),
        _wire('n3', 'r3-n', 'v1-n'),
        _wire('ns2', 'v2-n', 'v1-n'),
        _wire('ns3', 'v3-n', 'v1-n'),
      ],
      sources: <SourceInstance>[
        _source('v1', PhaseTag.l1),
        _source('v2', PhaseTag.l2),
        _source('v3', PhaseTag.l3),
      ],
      settings: const <String, Object?>{'frequencyHz': 50.0},
    );

ComponentInstance _load(String id, PhaseTag phase) => ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: <Terminal>[
        _t('$id-p', 'L', phase: phase),
        _t('$id-n', 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 23.0},
    );

SourceInstance _source(String id, PhaseTag phase) => SourceInstance(
      id: SourceId(id),
      modelType: 'ac_voltage_source',
      terminals: <Terminal>[
        _t('$id-p', phase.name, phase: phase),
        _t('$id-n', 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'voltageRmsV': 230.0},
    );

Terminal _t(
  String id,
  String name, {
  PhaseTag phase = PhaseTag.none,
}) =>
    Terminal(id: TerminalId(id), name: name, phase: phase);

Connection _wire(String id, String from, String to) => Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(from),
      toTerminalId: TerminalId(to),
    );
