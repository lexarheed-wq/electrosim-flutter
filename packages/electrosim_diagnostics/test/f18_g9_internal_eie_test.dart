import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  final CircuitId circuitId = CircuitId('f18-g9-pv');

  TopologyGraph topology() => TopologyGraph(
    circuitId: circuitId,
    circuitRevision: 9,
    mode: ElectricalMode.pv,
    nodes: const <TopologyNode>[],
    terminalToNode: const <TerminalId, String>{},
    enabledConnectionIds: const <ConnectionId>[],
    disabledConnectionIds: const <ConnectionId>[],
    componentNodeIds: const <ComponentId, List<String>>{},
    sourceNodeIds: const <SourceId, List<String>>{},
    findings: const <TopologyFinding>[],
  );

  test('F18-G9 clean PV evidence stays silent', () {
    final DiagnosticReport report = const DiagnosticEngine().analyzePv(
      topology: topology(),
      simulation: _pv(circuitId),
    );

    expect(report.status, DiagnosticReportStatus.insufficientEvidence);
    expect(report.advice, isEmpty);
    expect(report.evidence, isEmpty);
  });

  test('F18-G9 PV inverter fault is evidence-backed', () {
    final DiagnosticReport report = const DiagnosticEngine().analyzePv(
      topology: topology(),
      simulation: _pv(
        circuitId,
        diagnostics: <PvSolverDiagnostic>[
          PvSolverDiagnostic(
            code: PvDiagnosticCode.inverterFaulted,
            severity: PvDiagnosticSeverity.error,
            message: 'Onduleur en défaut confirmé par SolverPV.',
            componentId: ComponentId('inv'),
          ),
        ],
      ),
    );

    expect(report.status, DiagnosticReportStatus.evidenceAvailable);
    expect(report.advice, hasLength(1));
    expect(report.advice.single.code, EieAdviceCode.pvInverterFaulted);
    expect(report.advice.single.highlightTargetIds, contains('inv'));
    expect(report.advice.single.evidenceIds, hasLength(1));

    final String evidenceId = report.advice.single.evidenceIds.single;
    final DiagnosticEvidence evidence = report.evidence.singleWhere(
      (DiagnosticEvidence item) => item.id == evidenceId,
    );
    expect(evidence.source, DiagnosticEvidenceSource.solver);
    expect(evidence.summary, contains('SolverPV'));
  });

  test('F18-G9 disconnected PV DC input does not invent a cause', () {
    const String solverMessage =
        'The inverter DC input is not connected to the PV source.';
    final DiagnosticReport report = const DiagnosticEngine().analyzePv(
      topology: topology(),
      simulation: _pv(
        circuitId,
        diagnostics: <PvSolverDiagnostic>[
          PvSolverDiagnostic(
            code: PvDiagnosticCode.dcInputDisconnected,
            severity: PvDiagnosticSeverity.error,
            message: solverMessage,
            componentId: ComponentId('inv'),
          ),
        ],
      ),
    );

    expect(report.advice.single.code, EieAdviceCode.pvDcInputDisconnected);
    expect(report.evidence.single.summary, solverMessage);
    expect(
      report.advice.single.explanation,
      contains('provient directement du moteur de calcul'),
    );
  });
}

PvSolveResult _pv(
  CircuitId circuitId, {
  Iterable<PvSolverDiagnostic> diagnostics = const <PvSolverDiagnostic>[],
}) => PvSolveResult(
  circuitId: circuitId,
  circuitRevision: 9,
  engineVersion: 'test',
  status: diagnostics.any(
    (PvSolverDiagnostic item) => item.severity == PvDiagnosticSeverity.error,
  )
      ? PvSolveStatus.invalid
      : PvSolveStatus.solved,
  irradianceWm2: 1000,
  cellTemperatureC: 25,
  pvOperatingVoltageV: 400,
  pvAvailableCurrentA: 10,
  pvAvailablePowerW: 4000,
  pvDrawnCurrentA: 5,
  pvDrawnPowerW: 2000,
  curtailedPowerW: 2000,
  inverterState: PvInverterState.running,
  inverterEfficiency: 0.95,
  inverterOutputVoltageRmsV: 230,
  inverterOutputCurrentRmsA: 8.7,
  inverterOutputPowerW: 1900,
  inverterConversionLossW: 100,
  loadResults: const <PvLoadResult>[],
  diagnostics: diagnostics,
);
