
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_protection/electrosim_protection.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const ProtectionCoordinator protections = ProtectionCoordinator();

  test('DC breaker magnetic trip opens the real circuit immediately', () {
    final CircuitState circuit = _dcBreakerCircuit(
      ratedCurrentA: 2.0,
      resistanceOhm: 0.1,
    );
    final ProtectionDcOutcome outcome = protections.advanceDc(
      circuit: circuit,
      topology: topologyEngine.compile(circuit),
      elapsed: Duration.zero,
    );

    final ProtectionDeviceState state = outcome.state[ComponentId('q1')]!;
    expect(state.tripped, isTrue);
    expect(state.tripCause, ProtectionTripCause.magneticInstantaneous);
    expect(state.lastObservedCurrentA, closeTo(240.0, 1e-7));
    expect(outcome.result.isSolved, isTrue);
    expect(outcome.result.branch('component:q1').currentA, closeTo(0.0, 1e-12));
    expect(outcome.result.branch('component:r1').currentA, closeTo(0.0, 1e-12));
  });

  test('AC1 breaker integrates time-current exposure before physical opening',
      () {
    final CircuitState circuit = _ac1BreakerCircuit(
      ratedCurrentA: 5.0,
      resistanceOhm: 230.0 / 12.75,
    );
    final TopologyGraph topology = topologyEngine.compile(circuit);

    final ProtectionAc1Outcome half = protections.advanceAc1(
      circuit: circuit,
      topology: topology,
      elapsed: const Duration(seconds: 30),
    );
    expect(half.state[ComponentId('q1')]!.tripped, isFalse);
    expect(
      half.state[ComponentId('q1')]!.exposure.exposure,
      closeTo(0.5, 1e-7),
    );
    expect(
      half.result.branch('component:r1').current!.magnitude,
      closeTo(12.75, 1e-7),
    );

    final ProtectionAc1Outcome tripped = protections.advanceAc1(
      circuit: circuit,
      topology: topology,
      elapsed: const Duration(seconds: 30),
      previous: half.state,
    );
    expect(tripped.state[ComponentId('q1')]!.tripped, isTrue);
    expect(
      tripped.state[ComponentId('q1')]!.tripCause,
      ProtectionTripCause.timeCurrent,
    );
    expect(tripped.result.isSolved, isTrue);
    expect(
      tripped.result.branch('component:r1').current!.magnitude,
      closeTo(0.0, 1e-12),
    );
  });

  test('AC3 thermal overload opens all three poles after accumulated time', () {
    final CircuitState circuit = _ac3ThermalCircuit(
      ratedCurrentA: 5.0,
      resistanceOhm: 23.0,
    );
    final TopologyGraph topology = topologyEngine.compile(circuit);

    final ProtectionAc3Outcome half = protections.advanceAc3(
      circuit: circuit,
      topology: topology,
      elapsed: const Duration(seconds: 60),
    );
    expect(half.state[ComponentId('rt1')]!.tripped, isFalse);
    expect(
      half.state[ComponentId('rt1')]!.exposure.exposure,
      closeTo(0.5, 1e-7),
    );
    for (final String id in <String>['r1', 'r2', 'r3']) {
      expect(
        half.result.branch('component:$id').current!.magnitude,
        closeTo(10.0, 1e-7),
      );
    }

    final ProtectionAc3Outcome tripped = protections.advanceAc3(
      circuit: circuit,
      topology: topology,
      elapsed: const Duration(seconds: 60),
      previous: half.state,
    );
    expect(tripped.state[ComponentId('rt1')]!.tripped, isTrue);
    expect(
      tripped.state[ComponentId('rt1')]!.tripCause,
      ProtectionTripCause.timeCurrent,
    );
    expect(tripped.result.isSolved, isTrue);
    for (final String phase in <String>['L1', 'L2', 'L3']) {
      expect(
        tripped.result
            .branch('component:rt1:power:$phase')
            .current!
            .magnitude,
        closeTo(0.0, 1e-12),
      );
    }
    for (final String id in <String>['r1', 'r2', 'r3']) {
      expect(
        tripped.result.branch('component:$id').current!.magnitude,
        closeTo(0.0, 1e-12),
      );
    }
  });

  test('tripped protection is latched until explicit reset', () {
    final CircuitState circuit = _dcBreakerCircuit(
      ratedCurrentA: 2.0,
      resistanceOhm: 0.1,
    );
    final TopologyGraph topology = topologyEngine.compile(circuit);
    final ProtectionDcOutcome tripped = protections.advanceDc(
      circuit: circuit,
      topology: topology,
      elapsed: Duration.zero,
    );
    expect(tripped.state.isTripped(ComponentId('q1')), isTrue);

    final ProtectionRuntimeState reset =
        tripped.state.reset(ComponentId('q1'));
    expect(reset.isTripped(ComponentId('q1')), isFalse);
  });
}

CircuitState _dcBreakerCircuit({
  required double ratedCurrentA,
  required double resistanceOhm,
}) =>
    CircuitState(
      circuitId: CircuitId('protection-dc'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('q1'),
          modelType: 'breaker_dc',
          terminals: <Terminal>[
            _t('q-in', 'IN'),
            _t('q-out', 'OUT'),
          ],
          parameters: <String, Object?>{
            ProtectionRating.ratedCurrentKey: ratedCurrentA,
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
          parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
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

CircuitState _ac1BreakerCircuit({
  required double ratedCurrentA,
  required double resistanceOhm,
}) =>
    CircuitState(
      circuitId: CircuitId('protection-ac1'),
      revision: 0,
      mode: ElectricalMode.ac1,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('q1'),
          modelType: 'breaker_ac1',
          terminals: <Terminal>[
            _t('q-in', 'IN', phase: PhaseTag.l1),
            _t('q-out', 'OUT', phase: PhaseTag.l1),
          ],
          parameters: <String, Object?>{
            ProtectionRating.ratedCurrentKey: ratedCurrentA,
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
          terminals: <Terminal>[
            _t('r-in', 'L', phase: PhaseTag.l1),
            _t('r-out', 'N', phase: PhaseTag.neutral),
          ],
          parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
        ),
      ],
      connections: <Connection>[
        _wire('w1', 'vl', 'q-in'),
        _wire('w2', 'q-out', 'r-in'),
        _wire('w3', 'r-out', 'vn'),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v1'),
          modelType: 'ac_voltage_source',
          terminals: <Terminal>[
            _t('vl', 'L', phase: PhaseTag.l1),
            _t('vn', 'N', phase: PhaseTag.neutral),
          ],
          parameters: const <String, Object?>{'voltageRmsV': 230.0},
        ),
      ],
      settings: const <String, Object?>{'frequencyHz': 50.0},
    );

CircuitState _ac3ThermalCircuit({
  required double ratedCurrentA,
  required double resistanceOhm,
}) =>
    CircuitState(
      circuitId: CircuitId('protection-ac3'),
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
            ProtectionRating.ratedCurrentKey: ratedCurrentA,
          },
          controlState: const <String, Object?>{
            'closed': true,
            'tripped': false,
          },
        ),
        _load('r1', PhaseTag.l1, resistanceOhm),
        _load('r2', PhaseTag.l2, resistanceOhm),
        _load('r3', PhaseTag.l3, resistanceOhm),
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
        _phaseSource('v1', PhaseTag.l1),
        _phaseSource('v2', PhaseTag.l2),
        _phaseSource('v3', PhaseTag.l3),
      ],
      settings: const <String, Object?>{'frequencyHz': 50.0},
    );

ComponentInstance _load(
  String id,
  PhaseTag phase,
  double resistanceOhm,
) =>
    ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: <Terminal>[
        _t('$id-p', 'L', phase: phase),
        _t('$id-n', 'N', phase: PhaseTag.neutral),
      ],
      parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
    );

SourceInstance _phaseSource(String id, PhaseTag phase) => SourceInstance(
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
