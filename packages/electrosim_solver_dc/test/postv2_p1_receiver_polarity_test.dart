import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverDC solver = SolverDC();

  DcSolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('Post-V2 P1.4 receiver polarity behavior', () {
    for (final String modelType in <String>['resistor', 'lamp']) {
      test('P1-RX-${modelType.toUpperCase()} reversed wiring keeps magnitude', () {
        final DcBranchResult normal = solve(
          _singleReceiver(modelType: modelType, reversed: false),
        ).branch('component:load');
        final DcBranchResult reversed = solve(
          _singleReceiver(modelType: modelType, reversed: true),
        ).branch('component:load');

        expect(normal.currentA, isNotNull);
        expect(reversed.currentA, isNotNull);
        expect(normal.currentA!.abs(), closeTo(reversed.currentA!.abs(), 1e-9));
        expect(normal.voltageV.abs(), closeTo(reversed.voltageV.abs(), 1e-9));
        expect(normal.currentA!.sign, equals(-reversed.currentA!.sign));
        expect(normal.voltageV.sign, equals(-reversed.voltageV.sign));
      });
    }

    test('P1-RX-MOTOR-DC polarity reversal reverses signed motor current', () {
      final DcSolveResult normal = solve(
        _singleReceiver(modelType: 'motor_dc', reversed: false),
      );
      final DcSolveResult reversed = solve(
        _singleReceiver(modelType: 'motor_dc', reversed: true),
      );

      expect(normal.status, DcSolveStatus.solved);
      expect(reversed.status, DcSolveStatus.solved);
      final DcBranchResult forward = normal.branch('component:load');
      final DcBranchResult reverse = reversed.branch('component:load');
      expect(forward.currentA, isNotNull);
      expect(reverse.currentA, isNotNull);
      expect(forward.currentA!.abs(), closeTo(reverse.currentA!.abs(), 1e-9));
      expect(forward.currentA!.sign, equals(-reverse.currentA!.sign));
    });

    test('P1-RX-COIL-SIMPLE simple DC relay coil is electrically reversible', () {
      final DcBranchResult normal = solve(
        _singleReceiver(modelType: 'relay_coil', reversed: false),
      ).branch('component:load');
      final DcBranchResult reversed = solve(
        _singleReceiver(modelType: 'relay_coil', reversed: true),
      ).branch('component:load');

      expect(normal.currentA!.abs(), closeTo(reversed.currentA!.abs(), 1e-9));
      expect(normal.currentA!.sign, equals(-reversed.currentA!.sign));
    });

    test('P1-RX-LED forward conducts and reverse blocks', () {
      final DcSolveResult forward = solve(_ledCircuit(reversed: false));
      final DcSolveResult reverse = solve(_ledCircuit(reversed: true));

      expect(forward.status, DcSolveStatus.solved);
      expect(reverse.status, DcSolveStatus.solved);
      final DcBranchResult ledForward = forward.branch('component:led');
      final DcBranchResult ledReverse = reverse.branch('component:led');
      expect(ledForward.voltageV, closeTo(2.0, 1e-9));
      expect(ledForward.currentA!.abs(), greaterThan(0.04));
      expect(ledReverse.currentA!.abs(), lessThan(1e-9));
    });

    test(
      'P1-RX-COIL-POLARIZED coil plus integrated-diode equivalent is polarity sensitive',
      () {
        final DcSolveResult normal = solve(_polarizedCoilAssembly(reversed: false));
        final DcSolveResult reversed = solve(_polarizedCoilAssembly(reversed: true));

        expect(normal.status, DcSolveStatus.solved);
        expect(reversed.status, DcSolveStatus.solved);

        final DcBranchResult normalDiode = normal.branch('component:flyback');
        final DcBranchResult reversedDiode = reversed.branch('component:flyback');
        final DcBranchResult normalCoil = normal.branch('component:coil');
        final DcBranchResult reversedCoil = reversed.branch('component:coil');

        expect(normalDiode.currentA!.abs(), lessThan(1e-9));
        expect(reversedDiode.voltageV, closeTo(0.7, 1e-9));
        expect(reversedDiode.currentA!.abs(), greaterThan(0.20));
        expect(normalCoil.voltageV, greaterThan(10.0));
        expect(reversedCoil.voltageV.abs(), closeTo(0.7, 1e-9));
      },
    );
  });
}

CircuitState _singleReceiver({
  required String modelType,
  required bool reversed,
}) {
  final Terminal sourcePositive = _terminal(
    'vp',
    '+',
    role: TerminalRole.positive,
    phase: PhaseTag.dcPositive,
  );
  final Terminal sourceNegative = _terminal(
    'vn',
    '-',
    role: TerminalRole.negative,
    phase: PhaseTag.dcNegative,
  );
  final Terminal a = _terminal('load-a', 'A');
  final Terminal b = _terminal('load-b', 'B');

  return CircuitState(
    circuitId: CircuitId('p1-$modelType-$reversed'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('load'),
        modelType: modelType,
        terminals: <Terminal>[a, b],
        parameters: const <String, Object?>{'resistanceOhm': 24.0},
      ),
    ],
    connections: reversed
        ? <Connection>[
            _wire('w1', sourcePositive.id, b.id),
            _wire('w2', a.id, sourceNegative.id),
          ]
        : <Connection>[
            _wire('w1', sourcePositive.id, a.id),
            _wire('w2', b.id, sourceNegative.id),
          ],
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v1'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[sourcePositive, sourceNegative],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
  );
}

CircuitState _ledCircuit({required bool reversed}) {
  final Terminal p = _terminal('vp', '+');
  final Terminal n = _terminal('vn', '-');
  final Terminal ra = _terminal('ra', 'A');
  final Terminal rb = _terminal('rb', 'B');
  final Terminal anode = _terminal('led-a', 'A', role: TerminalRole.input);
  final Terminal cathode = _terminal('led-k', 'K', role: TerminalRole.output);

  return CircuitState(
    circuitId: CircuitId('p1-led-$reversed'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('r'),
        modelType: 'resistor',
        terminals: <Terminal>[ra, rb],
        parameters: const <String, Object?>{'resistanceOhm': 220.0},
      ),
      ComponentInstance(
        id: ComponentId('led'),
        modelType: 'diode',
        terminals: <Terminal>[anode, cathode],
        parameters: const <String, Object?>{'forwardVoltageV': 2.0},
      ),
    ],
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[p, n],
        parameters: const <String, Object?>{'voltageV': 12.0},
      ),
    ],
    connections: reversed
        ? <Connection>[
            _wire('w1', p.id, ra.id),
            _wire('w2', rb.id, cathode.id),
            _wire('w3', anode.id, n.id),
          ]
        : <Connection>[
            _wire('w1', p.id, ra.id),
            _wire('w2', rb.id, anode.id),
            _wire('w3', cathode.id, n.id),
          ],
  );
}

CircuitState _polarizedCoilAssembly({required bool reversed}) {
  final Terminal p = _terminal('vp', '+');
  final Terminal n = _terminal('vn', '-');
  final Terminal ra = _terminal('ra', 'A');
  final Terminal rb = _terminal('rb', 'B');
  final Terminal c1 = _terminal('c1', 'A1');
  final Terminal c2 = _terminal('c2', 'A2');
  final Terminal da = _terminal('da', 'A');
  final Terminal dk = _terminal('dk', 'K');

  return CircuitState(
    circuitId: CircuitId('p1-polarized-coil-$reversed'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('series'),
        modelType: 'resistor',
        terminals: <Terminal>[ra, rb],
        parameters: const <String, Object?>{'resistanceOhm': 100.0},
      ),
      ComponentInstance(
        id: ComponentId('coil'),
        modelType: 'relay_coil',
        terminals: <Terminal>[c1, c2],
        parameters: const <String, Object?>{
          'resistanceOhm': 120.0,
          'coilPickupVoltageV': 18.0,
          'coilDropoutVoltageV': 6.0,
        },
      ),
      ComponentInstance(
        id: ComponentId('flyback'),
        modelType: 'diode',
        terminals: <Terminal>[da, dk],
        parameters: const <String, Object?>{'forwardVoltageV': 0.7},
      ),
    ],
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[p, n],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    connections: reversed
        ? <Connection>[
            _wire('w1', p.id, c2.id),
            _wire('w2', c1.id, rb.id),
            _wire('w3', ra.id, n.id),
            _wire('w4', da.id, c2.id),
            _wire('w5', dk.id, c1.id),
          ]
        : <Connection>[
            _wire('w1', p.id, ra.id),
            _wire('w2', rb.id, c1.id),
            _wire('w3', c2.id, n.id),
            _wire('w4', da.id, c2.id),
            _wire('w5', dk.id, c1.id),
          ],
  );
}

Terminal _terminal(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

Connection _wire(String id, TerminalId from, TerminalId to) =>
    Connection(id: ConnectionId(id), fromTerminalId: from, toTerminalId: to);
