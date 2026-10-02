import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter/foundation.dart';

final class ElectroSimTpSessionController extends ChangeNotifier {
  ElectroSimTpSessionController({
    QualifiedCatalog? catalog,
    this.tpIdValue = 'TP04-F18',
    this.title = 'TP 04 · Circuit d’éclairage 24 V',
    String scenarioId = 'FAULT-F18-004',
  })  : _catalog = catalog ?? buildF18ProductCatalog(),
        _scenarioId = FaultScenarioId(scenarioId) {
    _engine = _buildEngine();
  }

  final QualifiedCatalog _catalog;
  final String tpIdValue;
  final String title;
  final FaultScenarioId _scenarioId;
  late TpEngine _engine;

  TpEngine _buildEngine() => TpEngine(
        faultScenarios: FaultScenarioRepository(
          scenarios: _catalog.faultScenarios,
        ),
      );

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

  /// JSON-compatible snapshot used by the application persistence layer.
  ///
  /// It contains no scenario teacher truth: only the public TP identity,
  /// lifecycle, current student circuit, diagnostic answers and score.
  Map<String, Object?> toPersistenceJson() {
    final TpSession? current = _session;
    if (current == null) {
      return const <String, Object?>{'hasSession': false};
    }
    return <String, Object?>{
      'hasSession': true,
      'tpId': tpIdValue,
      'title': title,
      'scenarioId': _scenarioId.value,
      'lifecycle': current.lifecycle.name,
      'studentCircuit': current.studentCircuit.toJson(),
      'diagnosticEntries': current.diagnosticSheet.entries
          .map((DiagnosticEntry entry) => entry.toJson())
          .toList(growable: false),
      if (current.evaluation != null)
        'teacherScore': current.evaluation!.score,
    };
  }

  /// Restores a TP session by replaying validated TpEngine transitions.
  ///
  /// Replaying transitions instead of injecting private engine state keeps all
  /// lifecycle and verification invariants active during recovery.
  void restoreFromPersistenceJson(Map<String, Object?> json) {
    _engine = _buildEngine();
    _session = null;

    if (json['hasSession'] != true) {
      notifyListeners();
      return;
    }
    if (json['tpId'] != tpIdValue ||
        json['title'] != title ||
        json['scenarioId'] != _scenarioId.value) {
      throw const FormatException('Saved TP identity does not match this controller.');
    }

    final Object? lifecycleRaw = json['lifecycle'];
    if (lifecycleRaw is! String) {
      throw const FormatException('Saved TP lifecycle is missing.');
    }
    final TpLifecycle lifecycle = TpLifecycle.values.firstWhere(
      (TpLifecycle value) => value.name == lifecycleRaw,
      orElse: () => throw FormatException('Unknown TP lifecycle: $lifecycleRaw'),
    );

    createDraft();
    if (lifecycle == TpLifecycle.draft) {
      return;
    }

    publish();
    if (lifecycle == TpLifecycle.published) {
      return;
    }

    startStudent();
    final Object? circuitRaw = json['studentCircuit'];
    if (circuitRaw is! Map<String, dynamic>) {
      throw const FormatException('Saved TP studentCircuit is missing.');
    }
    updateStudentCircuit(CircuitState.fromJson(circuitRaw));

    final Object? entriesRaw = json['diagnosticEntries'];
    if (entriesRaw is! List) {
      throw const FormatException('Saved TP diagnostic entries are invalid.');
    }
    for (final Object? raw in entriesRaw) {
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Saved TP diagnostic entry is invalid.');
      }
      final Object? promptId = raw['promptId'];
      final Object? answer = raw['answer'];
      if (promptId is! String || answer is! String) {
        throw const FormatException('Saved TP diagnostic entry fields are invalid.');
      }
      addDiagnosticEntry(promptId: promptId, answer: answer);
    }

    if (lifecycle == TpLifecycle.started) {
      return;
    }

    submitStudent();
    if (lifecycle == TpLifecycle.submitted) {
      return;
    }

    final Object? scoreRaw = json['teacherScore'];
    final int? score = scoreRaw is int ? scoreRaw : null;
    evaluateTeacher(score: score);
    if (lifecycle == TpLifecycle.evaluated) {
      return;
    }

    closeTeacher();
  }
}
