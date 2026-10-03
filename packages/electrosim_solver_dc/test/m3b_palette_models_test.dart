import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverDC solver = SolverDC();

  DcSolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('M3B palette/engine parity', () {
    for (final MapEntry<String, double> entry
        in const <String, double>{
          'buzzer': 48.0,
          'fan_dc': 12.0,
          'motor_dc': 8.0,
          'relay_coil': 120.0,
        }.entries) {
      test('${entry.key} is a canonical resistive DC branch', () {
        final CircuitState circuit = _componentCircuit(
          modelType: entry.key,
          resistanceOhm: entry.value,
        );
        final DcSolveResult result = solve(circuit);
        expect(result.status, DcSolveStatus.solved);
        expect(
          result.branch('component:x1').currentA?.abs(),
          closeTo(24.0 / (entry.value + 12.0), 1e-9),
        );
        _expectResiduals(result);
      });
    }

    test('push_button_no is open when released and closed when pressed', () {
      final DcSolveResult released = solve(
        _componentCircuit(
          modelType: 'push_button_no',
          controlState: const <String, Object?>{'pressed': false},
        ),
      );
      expect(released.status, DcSolveStatus.solved);
      expect(released.branch('component:x1').kind, DcBranchKind.openCircuit);
      expect(released.branch('component:r1').currentA, closeTo(0.0, 1e-12));

      final DcSolveResult pressed = solve(
        _componentCircuit(
          modelType: 'push_button_no',
          controlState: const <String, Object?>{'pressed': true},
        ),
      );
      expect(pressed.status, DcSolveStatus.solved);
      expect(pressed.branch('component:x1').kind, DcBranchKind.idealSwitch);
      expect(pressed.branch('component:r1').currentA?.abs(), closeTo(2.0, 1e-9));
      _expectResiduals(pressed);
    });

    test('relay coil topology branch keeps controlCoil semantics', () {
      final CircuitState circuit = _componentCircuit(
        modelType: 'relay_coil',
        resistanceOhm: 120.0,
      );
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final TopologyBranch branch =
          topology.branchesForComponent(ComponentId('x1')).single;
      expect(branch.role, ElectricalBranchRole.controlCoil);
    });

    test('non canonical breaker/fuse aliases are not silently accepted', () {
      for (final String modelType in <String>['breaker', 'fuse']) {
        final DcSolveResult result = solve(
          _componentCircuit(
            modelType: modelType,
            parameters: const <String, Object?>{
              'protectionRatedCurrentA': 10.0,
            },
          ),
        );
        expect(result.status, DcSolveStatus.invalid);
        expect(
          result.diagnostics.map((DcSolverDiagnostic d) => d.code),
          contains(DcDiagnosticCode.unsupportedComponentModel),
        );
      }
    });
  });
}

CircuitState _componentCircuit({
  required String modelType,
  double? resistanceOhm,
  Map<String, Object?> parameters = const <String, Object?>{},
  Map<String, Object?> controlState = const <String, Object?>{},
}) {
  final bool switching = modelType == 'push_button_no' || modelType == 'push_button_nc';
  return CircuitState(
    circuitId: CircuitId('m3b-$modelType-${controlState['pressed'] ?? controlState['closed'] ?? 'load'}'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('x1'),
        modelType: modelType,
        terminals: <Terminal>[
          _terminal(
            'x1a',
            modelType == 'relay_coil' ? 'A1' : 'A',
            role: modelType == 'relay_coil'
                ? TerminalRole.coilA1
                : TerminalRole.input,
          ),
          _terminal(
            'x1b',
            modelType == 'relay_coil' ? 'A2' : 'B',
            role: modelType == 'relay_coil'
                ? TerminalRole.coilA2
                : TerminalRole.output,
          ),
        ],
        parameters: <String, Object?>{
          ...parameters,
          if (!switching && resistanceOhm != null)
            'resistanceOhm': resistanceOhm,
        },
        controlState: controlState,
      ),
      ComponentInstance(
        id: ComponentId('r1'),
        modelType: 'resistor',
        terminals: <Terminal>[
          _terminal('r1a', 'A'),
          _terminal('r1b', 'B'),
        ],
        parameters: const <String, Object?>{'resistanceOhm': 12.0},
      ),
    ],
    connections: <Connection>[
      Connection(
        id: ConnectionId('w1'),
        fromTerminalId: TerminalId('vp'),
        toTerminalId: TerminalId('x1a'),
      ),
      Connection(
        id: ConnectionId('w2'),
        fromTerminalId: TerminalId('x1b'),
        toTerminalId: TerminalId('r1a'),
      ),
      Connection(
        id: ConnectionId('w3'),
        fromTerminalId: TerminalId('r1b'),
        toTerminalId: TerminalId('vn'),
      ),
    ],
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v1'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[
          _terminal(
            'vp',
            '+',
            role: TerminalRole.positive,
            phase: PhaseTag.dcPositive,
          ),
          _terminal(
            'vn',
            '-',
            role: TerminalRole.negative,
            phase: PhaseTag.dcNegative,
          ),
        ],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
  );
}

Terminal _terminal(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

void _expectResiduals(DcSolveResult result) {
  expect(result.maxMatrixResidual, isNotNull);
  expect(result.maxMatrixResidual!, lessThan(1e-9));
  for (final double residual in result.kclResiduals.values) {
    expect(residual.abs(), lessThan(1e-9));
  }
  for (final double residual in result.kvlResiduals.values) {
    expect(residual.abs(), lessThan(1e-9));
  }
}
