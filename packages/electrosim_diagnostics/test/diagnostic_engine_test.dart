import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  final CircuitId circuitId = CircuitId('diag-test');

  DcSolveResult result({
    Iterable<DcSolverDiagnostic> diagnostics = const <DcSolverDiagnostic>[],
    Iterable<DcBranchResult> branches = const <DcBranchResult>[],
    int revision = 1,
  }) => DcSolveResult(
        circuitId: circuitId,
        circuitRevision: revision,
        engineVersion: 'test',
        status: DcSolveStatus.solved,
        referenceNodeId: 'node:ref',
        nodeVoltages: const <String,double>{},
        branchResults: branches,
        diagnostics: diagnostics,
        maxMatrixResidual: 0,
        kclResiduals: const <String,double>{},
        kvlResiduals: const <String,double>{},
      );

  TopologyGraph topology({Iterable<TopologyFinding> findings = const <TopologyFinding>[], int revision = 1}) => TopologyGraph(
        circuitId: circuitId,
        circuitRevision: revision,
        mode: ElectricalMode.dc,
        nodes: const <TopologyNode>[],
        terminalToNode: const <TerminalId,String>{},
        enabledConnectionIds: const <ConnectionId>[],
        disabledConnectionIds: const <ConnectionId>[],
        componentNodeIds: const <ComponentId,List<String>>{},
        sourceNodeIds: const <SourceId,List<String>>{},
        findings: findings,
      );

  test('insufficient evidence produces no invented advice', () {
    final report = const DiagnosticEngine().analyze(topology: topology(), simulation: result());
    expect(report.status, DiagnosticReportStatus.insufficientEvidence);
    expect(report.advice, isEmpty);
  });

  test('topology finding produces traceable advice and highlight targets', () {
    final report = const DiagnosticEngine().analyze(
      topology: topology(findings: <TopologyFinding>[
        TopologyFinding(
          code: TopologyFindingCode.floatingNode,
          severity: TopologyFindingSeverity.warning,
          message: 'Floating test node.',
          nodeId: 'node:x',
        ),
      ]),
      simulation: result(),
    );
    expect(report.advice, hasLength(1));
    expect(report.advice.single.evidenceIds, isNotEmpty);
    expect(report.advice.single.highlightTargetIds, contains('node:x'));
    expect(report.evidence.map((e) => e.id), contains(report.advice.single.evidenceIds.single));
  });

  test('solver diagnostic is cited, never inferred without evidence', () {
    final report = const DiagnosticEngine().analyze(
      topology: topology(),
      simulation: result(diagnostics: <DcSolverDiagnostic>[
        DcSolverDiagnostic(
          code: DcDiagnosticCode.singularMatrix,
          severity: DcDiagnosticSeverity.error,
          message: 'Matrix singular.',
          nodeIds: const <String>['node:a'],
        ),
      ]),
    );
    expect(report.advice.single.code, EieAdviceCode.singularNetwork);
    expect(report.advice.single.evidenceIds.single, startsWith('solver:singularMatrix:'));
  });

  test('open branch comes from simulation result and is locatable', () {
    final report = const DiagnosticEngine().analyze(
      topology: topology(),
      simulation: result(branches: const <DcBranchResult>[
        DcBranchResult(
          id: 'component:r1',
          modelType: 'resistor',
          kind: DcBranchKind.openCircuit,
          fromNodeId: 'node:a',
          toNodeId: 'node:b',
          voltageV: 12,
          currentA: 0,
          powerW: 0,
        ),
      ]),
    );
    expect(report.advice.single.code, EieAdviceCode.openBranch);
    expect(report.advice.single.highlightTargetIds, contains('component:r1'));
  });

  test('circuit revision mismatch is rejected', () {
    expect(
      () => const DiagnosticEngine().analyze(topology: topology(revision: 1), simulation: result(revision: 2)),
      throwsStateError,
    );
  });

  test('report constructor rejects advice referencing missing evidence', () {
    expect(
      () => DiagnosticReport(
        circuitId: circuitId,
        circuitRevision: 1,
        status: DiagnosticReportStatus.evidenceAvailable,
        evidence: const <DiagnosticEvidence>[],
        advice: <EieAdvice>[
          EieAdvice(
            code: EieAdviceCode.singularNetwork,
            title: 'x',
            explanation: 'x',
            evidenceIds: const <String>['missing'],
          ),
        ],
      ),
      throwsStateError,
    );
  });
}
