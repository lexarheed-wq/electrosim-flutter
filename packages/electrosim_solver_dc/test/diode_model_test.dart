import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverDC solver = SolverDC();

  DcSolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  test('forward diode converges to its configured voltage drop', () {
    final DcSolveResult result = solve(_seriesDiode(reverse: false));
    expect(result.status, DcSolveStatus.solved);
    final DcBranchResult diode = result.branch('component:d1');
    expect(diode.kind, DcBranchKind.diode);
    expect(diode.voltageV, closeTo(0.7, 1e-9));
    expect(diode.currentA?.abs(), closeTo(0.043, 1e-9));
    expect(result.branch('component:r1').currentA?.abs(), closeTo(0.043, 1e-9));
  });

  test('reverse diode blocks current', () {
    final DcSolveResult result = solve(_seriesDiode(reverse: true));
    expect(result.status, DcSolveStatus.solved);
    final DcBranchResult diode = result.branch('component:d1');
    expect(diode.kind, DcBranchKind.diode);
    expect(diode.currentA?.abs() ?? 0, lessThan(1e-9));
    expect(result.branch('component:r1').currentA?.abs() ?? 0, lessThan(1e-9));
    expect(diode.voltageV, lessThan(0));
  });

  test('Zener diode clamps reverse voltage at configured breakdown', () {
    final CircuitState circuit = _seriesDiode(
      reverse: true,
      sourceVoltageV: 12.0,
      resistanceOhm: 1000.0,
      diodeParameters: const <String, Object?>{
        'forwardVoltageV': 0.7,
        'reverseBreakdownVoltageV': 5.1,
      },
    );
    final DcSolveResult result = solve(circuit);
    expect(result.status, DcSolveStatus.solved);
    final DcBranchResult diode = result.branch('component:d1');
    expect(diode.kind, DcBranchKind.diode);
    expect(diode.voltageV, closeTo(-5.1, 1e-9));
    expect(diode.currentA?.abs(), closeTo(0.0069, 1e-9));
    expect(
      result.branch('component:r1').currentA?.abs(),
      closeTo(0.0069, 1e-9),
    );
  });



  test('finite diode series resistance keeps direct 24 V source solvable', () {
    final Terminal vp = _t('direct-vp', '+', phase: PhaseTag.dcPositive);
    final Terminal vn = _t('direct-vn', '−', phase: PhaseTag.dcNegative);
    final Terminal a = _t('direct-a', 'A', role: TerminalRole.input);
    final Terminal k = _t('direct-k', 'K', role: TerminalRole.output);
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('diode-direct-source'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('d1'),
          modelType: 'diode',
          terminals: <Terminal>[a, k],
          parameters: const <String, Object?>{
            ComponentParameterKeys.forwardVoltageV: 2.0,
            ComponentParameterKeys.seriesResistanceOhm: 5.0,
          },
        ),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[vp, vn],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      connections: <Connection>[
        _w('direct-p', vp.id, a.id),
        _w('direct-n', k.id, vn.id),
      ],
    );

    final DcSolveResult result = solve(circuit);
    expect(result.status, DcSolveStatus.solved);
    final DcBranchResult diode = result.branch('component:d1');
    expect(diode.voltageV, closeTo(24.0, 1e-9));
    expect(diode.currentA, closeTo(4.4, 1e-9));
  });

  test('diode parameters are validated', () {
    final CircuitState circuit = _seriesDiode(
      reverse: false,
      diodeParameters: const <String, Object?>{'forwardVoltageV': -1.0},
    );
    final DcSolveResult result = solve(circuit);
    expect(result.status, DcSolveStatus.invalid);
    expect(
      result.diagnostics.map((DcSolverDiagnostic d) => d.code),
      contains(DcDiagnosticCode.invalidParameter),
    );
  });
}

CircuitState _seriesDiode({
  required bool reverse,
  double sourceVoltageV = 5.0,
  double resistanceOhm = 100.0,
  Map<String, Object?> diodeParameters = const <String, Object?>{},
}) {
  final Terminal vp = _t('vp', '+', phase: PhaseTag.dcPositive);
  final Terminal vn = _t('vn', '−', phase: PhaseTag.dcNegative);
  final Terminal a = _t('da', 'A', role: TerminalRole.input);
  final Terminal k = _t('dk', 'K', role: TerminalRole.output);
  final Terminal r1a = _t('r1a', '1');
  final Terminal r1b = _t('r1b', '2');

  return CircuitState(
    circuitId: CircuitId(reverse ? 'diode-reverse' : 'diode-forward'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('d1'),
        modelType: 'diode',
        terminals: <Terminal>[a, k],
        parameters: diodeParameters,
      ),
      ComponentInstance(
        id: ComponentId('r1'),
        modelType: 'resistor',
        terminals: <Terminal>[r1a, r1b],
        parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
      ),
    ],
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v1'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[vp, vn],
        parameters: <String, Object?>{'voltageV': sourceVoltageV},
      ),
    ],
    connections: reverse
        ? <Connection>[
            _w('w1', vp.id, k.id),
            _w('w2', a.id, r1a.id),
            _w('w3', r1b.id, vn.id),
          ]
        : <Connection>[
            _w('w1', vp.id, a.id),
            _w('w2', k.id, r1a.id),
            _w('w3', r1b.id, vn.id),
          ],
  );
}

Connection _w(String id, TerminalId from, TerminalId to) =>
    Connection(id: ConnectionId(id), fromTerminalId: from, toTerminalId: to);

Terminal _t(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);
