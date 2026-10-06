import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverDC solver = SolverDC();

  group('Post-V2 P1.5 electrical invariants', () {
    test('P1-INV-DC KCL KVL power and finiteness close simultaneously', () {
      final CircuitState circuit = _circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final DcSolveResult result = solver.solve(circuit, topology);

      expect(result.status, DcSolveStatus.solved);
      expect(result.maxMatrixResidual, isNotNull);
      expect(result.maxMatrixResidual!.isFinite, isTrue);
      expect(result.maxMatrixResidual!, lessThan(1e-9));

      for (final double value in result.nodeVoltages.values) {
        expect(value.isFinite, isTrue);
      }
      for (final DcBranchResult branch in result.branchResults) {
        expect(branch.voltageV.isFinite, isTrue);
        expect(branch.currentA == null || branch.currentA!.isFinite, isTrue);
        expect(branch.powerW == null || branch.powerW!.isFinite, isTrue);
      }
      for (final double residual in result.kclResiduals.values) {
        expect(residual.isFinite, isTrue);
        expect(residual.abs(), lessThan(1e-9));
      }
      for (final double residual in result.kvlResiduals.values) {
        expect(residual.isFinite, isTrue);
        expect(residual.abs(), lessThan(1e-9));
      }

      final double netPower = result.branchResults
          .where((DcBranchResult branch) => branch.powerW != null)
          .fold<double>(
            0.0,
            (double sum, DcBranchResult branch) => sum + branch.powerW!,
          );
      expect(netPower.abs(), lessThan(1e-8));
    });

    test('P1-INV-REPRO same canonical state is bitwise reproducible', () {
      final CircuitState circuit = _circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final DcSolveResult a = solver.solve(circuit, topology);
      final DcSolveResult b = solver.solve(circuit, topology);

      expect(a.status, b.status);
      expect(a.nodeVoltages, b.nodeVoltages);
      expect(a.maxMatrixResidual, b.maxMatrixResidual);
      expect(a.kclResiduals, b.kclResiduals);
      expect(a.kvlResiduals, b.kvlResiduals);
      expect(
        a.branchResults
            .map(
              (DcBranchResult item) => <Object?>[
                item.id,
                item.voltageV,
                item.currentA,
                item.powerW,
              ],
            )
            .toList(),
        b.branchResults
            .map(
              (DcBranchResult item) => <Object?>[
                item.id,
                item.voltageV,
                item.currentA,
                item.powerW,
              ],
            )
            .toList(),
      );
    });
  });
}

CircuitState _circuit() {
  final Terminal vp = _t('vp', '+');
  final Terminal vn = _t('vn', '-');
  final Terminal r1a = _t('r1a', 'A');
  final Terminal r1b = _t('r1b', 'B');
  final Terminal r2a = _t('r2a', 'A');
  final Terminal r2b = _t('r2b', 'B');

  return CircuitState(
    circuitId: CircuitId('p1-invariants'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('r1'),
        modelType: 'resistor',
        terminals: <Terminal>[r1a, r1b],
        parameters: const <String, Object?>{'resistanceOhm': 12.0},
      ),
      ComponentInstance(
        id: ComponentId('r2'),
        modelType: 'resistor',
        terminals: <Terminal>[r2a, r2b],
        parameters: const <String, Object?>{'resistanceOhm': 24.0},
      ),
    ],
    connections: <Connection>[
      _w('w1', vp.id, r1a.id),
      _w('w2', r1b.id, r2a.id),
      _w('w3', r2b.id, vn.id),
    ],
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[vp, vn],
        parameters: const <String, Object?>{'voltageV': 36.0},
      ),
    ],
  );
}

Terminal _t(String id, String name) => Terminal(id: TerminalId(id), name: name);

Connection _w(String id, TerminalId from, TerminalId to) =>
    Connection(id: ConnectionId(id), fromTerminalId: from, toTerminalId: to);
