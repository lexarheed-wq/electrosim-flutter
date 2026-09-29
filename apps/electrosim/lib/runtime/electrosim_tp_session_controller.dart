import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/foundation.dart';

final class ElectroSimTpSessionController extends ChangeNotifier {
  ElectroSimTpSessionController({
    QualifiedCatalog? catalog,
    this.tpIdValue = 'TP-RD-F17',
    this.title = 'Recherche de dérangement — F17',
    String scenarioId = 'FAULT-DC-003',
  })  : _catalog = catalog ?? buildF16QualifiedCatalog(),
        _scenarioId = FaultScenarioId(scenarioId) {
    _engine = TpEngine(
      faultScenarios: FaultScenarioRepository(
        scenarios: _catalog.faultScenarios,
      ),
    );
  }

  final QualifiedCatalog _catalog;
  final String tpIdValue;
  final String title;
  final FaultScenarioId _scenarioId;
  late final TpEngine _engine;

  TpId get tpId => TpId(tpIdValue);

  TpSession? _session;
  TpSession? get session => _session;

  bool get hasSession => _session != null;
  TpLifecycle? get lifecycle => _session?.lifecycle;
  bool get readOnly => _session?.readOnly ?? false;

  TpSession createDraft() {
    if (_session != null) {
      throw StateError('A TP session already exists.');
    }
    final definition = TpDefinition.troubleshooting(
      id: tpId,
      title: title,
      scenarioId: _scenarioId,
    );
    _session = _engine.createDraft(definition);
    notifyListeners();
    return _session!;
  }

  TpSession publish() {
    _session = _engine.publish(tpId);
    notifyListeners();
    return _session!;
  }

  TpSession startStudent() {
    _session = _engine.start(tpId);
    notifyListeners();
    return _session!;
  }

  TpSession updateStudentCircuit(CircuitState circuit) {
    _session = _engine.updateCircuit(tpId, circuit);
    notifyListeners();
    return _session!;
  }

  TpSession addDiagnosticEntry({
    required String promptId,
    required String answer,
  }) {
    _session = _engine.addDiagnosticEntry(
      tpId,
      DiagnosticEntry(promptId: promptId, answer: answer),
    );
    notifyListeners();
    return _session!;
  }

  TpSession submitStudent() {
    _session = _engine.submit(tpId);
    notifyListeners();
    return _session!;
  }

  TpSession evaluateTeacher({int? score}) {
    _session = _engine.evaluate(tpId, teacherScore: score);
    notifyListeners();
    return _session!;
  }

  TpSession closeTeacher() {
    _session = _engine.close(tpId);
    notifyListeners();
    return _session!;
  }

  CircuitState? get studentCircuit => _session?.studentCircuit;
  TpEvaluation? get evaluation => _session?.evaluation;

  Map<String, Object?>? payloadFor(TpRole role) =>
      _session?.payloadFor(role);
}
