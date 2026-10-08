import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  final CircuitId circuitId = CircuitId('m9');

  TopologyGraph topology({
    ElectricalMode mode = ElectricalMode.dc,
    Iterable<TopologyFinding> findings = const <TopologyFinding>[],
  }) => TopologyGraph(
    circuitId: circuitId,
    circuitRevision: 1,
    mode: mode,
    nodes: const <TopologyNode>[],
    terminalToNode: const <TerminalId, String>{},
    enabledConnectionIds: const <ConnectionId>[],
    disabledConnectionIds: const <ConnectionId>[],
    componentNodeIds: const <ComponentId, List<String>>{},
    sourceNodeIds: const <SourceId, List<String>>{},
    findings: findings,
  );

  test('M9 topology contract mismatch produces evidence-backed advice', () {
    final DiagnosticReport report = const DiagnosticEngine().analyze(
      topology: topology(
        findings: <TopologyFinding>[
          TopologyFinding(
            code: TopologyFindingCode.componentContractMismatch,
            severity: TopologyFindingSeverity.error,
            message: 'Bad terminal contract.',
            componentId: ComponentId('x1'),
          ),
        ],
      ),
      simulation: _dc(circuitId),
    );
    expect(report.status, DiagnosticReportStatus.evidenceAvailable);
    expect(
      report.advice.map((EieAdvice item) => item.code),
      contains(EieAdviceCode.componentContractMismatch),
    );
    expect(report.advice.single.evidenceIds, isNotEmpty);
  });

  test('M9 source current limiting is visible to EIE', () {
    final DiagnosticReport report = const DiagnosticEngine().analyze(
      topology: topology(),
      simulation: _dc(
        circuitId,
        diagnostics: <DcSolverDiagnostic>[
          DcSolverDiagnostic(
            code: DcDiagnosticCode.sourceCurrentLimited,
            severity: DcDiagnosticSeverity.warning,
            message: 'Source limited.',
            sourceId: SourceId('v1'),
          ),
        ],
      ),
    );
    expect(
      report.advice.map((EieAdvice item) => item.code),
      contains(EieAdviceCode.sourceCurrentLimited),
    );
  });

  test('M9 severe receiver overload cites measured and nominal current', () {
    final ReceiverLoadState state = ReceiverLoadState(
      componentId: ComponentId('m1'),
      code: ReceiverLoadCode.severeOverload,
      currentA: 3.0,
      ratedCurrentA: 1.5,
      loadRatio: 2.0,
    );
    final DiagnosticReport report = const DiagnosticEngine().analyze(
      topology: topology(),
      simulation: _dc(circuitId),
      receiverLoadStates: <ReceiverLoadState>[state],
    );
    expect(
      report.advice.map((EieAdvice item) => item.code),
      contains(EieAdviceCode.severeReceiverOverload),
    );
    expect(report.evidence.single.summary, contains('3.000 A'));
    expect(report.evidence.single.summary, contains('1.500 A'));
  });

  test('M9 AC3 phase loss is evidence-backed', () {
    final DiagnosticReport report = const DiagnosticEngine().analyzeAc3(
      topology: topology(mode: ElectricalMode.ac3),
      simulation: _ac3(
        circuitId,
        diagnostics: <Ac3SolverDiagnostic>[
          Ac3SolverDiagnostic(
            code: Ac3DiagnosticCode.phaseLoss,
            severity: Ac3DiagnosticSeverity.warning,
            message: 'L2 missing.',
            phase: PhaseTag.l2,
          ),
        ],
      ),
    );
    expect(
      report.advice.map((EieAdvice item) => item.code),
      contains(EieAdviceCode.phaseLoss),
    );
    expect(report.advice.single.highlightTargetIds, contains('phase:l2'));
  });

  test('M9 clean solved AC1 report stays silent', () {
    final DiagnosticReport report = const DiagnosticEngine().analyzeAc1(
      topology: topology(mode: ElectricalMode.ac1),
      simulation: _ac1(circuitId),
    );
    expect(report.status, DiagnosticReportStatus.insufficientEvidence);
    expect(report.advice, isEmpty);
  });

  test('M9 invalid motor coupling becomes evidence-backed EIE advice', () {
    final Ac3SolveResult simulation = Ac3SolveResult(
      circuitId: circuitId,
      circuitRevision: 1,
      engineVersion: 'test',
      status: Ac3SolveStatus.solved,
      frequencyHz: 50.0,
      referenceNodeId: 'n0',
      nodeVoltages: const <String, AcComplex>{},
      branchResults: const <Ac3BranchResult>[],
      diagnostics: <Ac3SolverDiagnostic>[
        Ac3SolverDiagnostic(
          code: Ac3DiagnosticCode.invalidMotorCoupling,
          severity: Ac3DiagnosticSeverity.warning,
          message: 'Couplage moteur 3φ incomplet.',
          componentId: ComponentId('m1'),
        ),
      ],
      maxMatrixResidual: 0.0,
      kclResiduals: const <String, double>{},
      phaseVoltages: const <PhaseTag, AcComplex>{},
      lineCurrents: const <PhaseTag, AcComplex>{},
      lineToLineVoltages: const <String, AcComplex>{},
      neutralCurrent: AcComplex.zero,
      missingPhases: const <PhaseTag>[],
      sourceSequence: Ac3PhaseSequence.positive,
      voltageBalanced: true,
      currentBalanced: true,
      neutralConnected: false,
      phaseOrderObservations: const <Ac3PhaseOrderObservation>[],
    );
    final DiagnosticReport report = const DiagnosticEngine().analyzeAc3(
      topology: topology(mode: ElectricalMode.ac3),
      simulation: simulation,
    );
    expect(
      report.advice.map((EieAdvice item) => item.code),
      contains(EieAdviceCode.invalidMotorCoupling),
    );
  });

}

DcSolveResult _dc(
  CircuitId id, {
  Iterable<DcSolverDiagnostic> diagnostics = const <DcSolverDiagnostic>[],
}) => DcSolveResult(
  circuitId: id,
  circuitRevision: 1,
  engineVersion: 'test',
  status: DcSolveStatus.solved,
  referenceNodeId: 'n0',
  nodeVoltages: const <String, double>{},
  branchResults: const <DcBranchResult>[],
  diagnostics: diagnostics,
  maxMatrixResidual: 0.0,
  kclResiduals: const <String, double>{},
  kvlResiduals: const <String, double>{},
);

Ac1SolveResult _ac1(CircuitId id) => Ac1SolveResult(
  circuitId: id,
  circuitRevision: 1,
  engineVersion: 'test',
  status: Ac1SolveStatus.solved,
  frequencyHz: 50.0,
  referenceNodeId: 'n0',
  nodeVoltages: const <String, AcComplex>{},
  branchResults: const <Ac1BranchResult>[],
  diagnostics: const <Ac1SolverDiagnostic>[],
  maxMatrixResidual: 0.0,
  kclResiduals: const <String, double>{},
);

Ac3SolveResult _ac3(
  CircuitId id, {
  Iterable<Ac3SolverDiagnostic> diagnostics = const <Ac3SolverDiagnostic>[],
}) => Ac3SolveResult(
  circuitId: id,
  circuitRevision: 1,
  engineVersion: 'test',
  status: Ac3SolveStatus.solved,
  frequencyHz: 50.0,
  referenceNodeId: 'n0',
  nodeVoltages: const <String, AcComplex>{},
  branchResults: const <Ac3BranchResult>[],
  diagnostics: diagnostics,
  maxMatrixResidual: 0.0,
  kclResiduals: const <String, double>{},
  phaseVoltages: const <PhaseTag, AcComplex>{},
  lineCurrents: const <PhaseTag, AcComplex>{},
  lineToLineVoltages: const <String, AcComplex>{},
  neutralCurrent: AcComplex.zero,
  missingPhases: const <PhaseTag>[],
  sourceSequence: Ac3PhaseSequence.positive,
  voltageBalanced: true,
  currentBalanced: true,
  neutralConnected: true,
  phaseOrderObservations: const <Ac3PhaseOrderObservation>[],
);
