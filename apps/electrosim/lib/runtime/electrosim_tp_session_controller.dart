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
  }) : _catalog = catalog ?? buildF16QualifiedCatalog(),
       _scenarioId = FaultScenarioId(scenarioId) {
    _engine = _buildEngine();
  }

  final QualifiedCatalog _catalog;
  final String tpIdValue;
  final String title;
  final FaultScenarioId _scenarioId;
  late TpEngine _engine;

  TpEngine _buildEngine() => TpEngine(
    faultScenarios: FaultScenarioRepository(scenarios: _catalog.faultScenarios),
  );

  TpId get tpId => TpId(tpIdValue);

  TpSession? _session;
  TpSession? get session => _session;

  bool get hasSession => _session != null;
  TpLifecycle? get lifecycle => _session?.lifecycle;
  bool get readOnly => _session?.readOnly ?? false;

  ElectroSimTpSessionController createStudentReplica({
    bool includeDraft = false,
  }) {
    final ElectroSimTpSessionController replica = ElectroSimTpSessionController(
      catalog: _catalog,
      tpIdValue: tpIdValue,
      title: title,
      scenarioId: _scenarioId.value,
    );
    final TpSession? current = _session;
    if (current != null &&
        (includeDraft || current.lifecycle != TpLifecycle.draft)) {
      replica.restoreFromPersistenceJson(toPersistenceJson());
    }
    return replica;
  }

  /// A session can hold one active teacher activity. The selected dashboard
  /// workspace decides the TP mode; the electrical engine is unchanged.
  TpSession createDraft({
    TpMode mode = TpMode.troubleshooting,
    CircuitState? wiringReferenceCircuit,
    String? activityTitle,
  }) {
    if (_session != null) {
      throw StateError('A TP session already exists.');
    }
    if (mode == TpMode.wiring &&
        (wiringReferenceCircuit == null ||
            wiringReferenceCircuit.sources.isEmpty ||
            wiringReferenceCircuit.components.isEmpty ||
            wiringReferenceCircuit.connections.isEmpty)) {
      throw StateError(
        'Préparez un montage de référence câblé ou choisissez un schéma V2.',
      );
    }
    final TpDefinition definition = switch (mode) {
      TpMode.wiring => TpDefinition.wiring(
        id: tpId,
        title: activityTitle ?? 'TP de câblage',
        referenceCircuit: wiringReferenceCircuit!,
      ),
      TpMode.troubleshooting => TpDefinition.troubleshooting(
        id: tpId,
        title: activityTitle ?? title,
        scenarioId: _scenarioId,
      ),
    };
    _session = _engine.createDraft(definition);
    notifyListeners();
    return _session!;
  }

  TpSession publish() {
    _session = _engine.publish(tpId);
    notifyListeners();
    return _session!;
  }

  TpSession startTeacher() {
    _session = _engine.start(tpId);
    notifyListeners();
    return _session!;
  }

  /// Replays a teacher-authorized started state on a student replica.
  ///
  /// Interactive student UI must not call this to obtain authority.
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

  TpSession cancelTeacher() {
    _session = _engine.cancel(tpId);
    notifyListeners();
    return _session!;
  }

  void deleteTeacherActivity() {
    final TpSession? current = _session;
    if (current == null) return;
    if (current.lifecycle == TpLifecycle.started ||
        current.lifecycle == TpLifecycle.submitted ||
        current.lifecycle == TpLifecycle.evaluated) {
      throw StateError(
        'Active, submitted or evaluated TP must be closed before deletion.',
      );
    }
    _engine = _buildEngine();
    _session = null;
    notifyListeners();
  }

  CircuitState? get studentCircuit => _session?.studentCircuit;
  TpEvaluation? get evaluation => _session?.evaluation;

  Map<String, Object?>? payloadFor(TpRole role) => _session?.payloadFor(role);

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
      'mode': current.definition.mode.name,
      'activityTitle': current.definition.title,
      if (current.definition.mode == TpMode.wiring)
        'referenceCircuit': current.definition.referenceCircuit!.toJson(),
      'lifecycle': current.lifecycle.name,
      'studentCircuit': current.studentCircuit.toJson(),
      'diagnosticEntries': current.diagnosticSheet.entries
          .map((DiagnosticEntry entry) => entry.toJson())
          .toList(growable: false),
      if (current.evaluation != null) 'teacherScore': current.evaluation!.score,
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
      throw const FormatException(
        'Saved TP identity does not match this controller.',
      );
    }

    final Object? lifecycleRaw = json['lifecycle'];
    if (lifecycleRaw is! String) {
      throw const FormatException('Saved TP lifecycle is missing.');
    }
    final TpLifecycle lifecycle = TpLifecycle.values.firstWhere(
      (TpLifecycle value) => value.name == lifecycleRaw,
      orElse: () =>
          throw FormatException('Unknown TP lifecycle: $lifecycleRaw'),
    );

    // Legacy F17 snapshots have no mode: they are troubleshooting TPs.
    final Object? savedMode = json['mode'];
    final TpMode mode = savedMode == 'wiring'
        ? TpMode.wiring
        : TpMode.troubleshooting;
    if (savedMode != null &&
        savedMode != TpMode.wiring.name &&
        savedMode != TpMode.troubleshooting.name) {
      throw const FormatException('Unknown TP mode.');
    }
    final Object? savedActivityTitle = json['activityTitle'];
    final String? activityTitle =
        savedActivityTitle is String && savedActivityTitle.trim().isNotEmpty
        ? savedActivityTitle
        : null;
    CircuitState? referenceCircuit;
    if (mode == TpMode.wiring) {
      final Object? referenceRaw =
          json['referenceCircuit'] ?? json['studentCircuit'];
      if (referenceRaw is! Map<String, dynamic>) {
        throw const FormatException('Wiring TP reference circuit is missing.');
      }
      referenceCircuit = CircuitState.fromJson(referenceRaw);
    }
    createDraft(
      mode: mode,
      wiringReferenceCircuit: referenceCircuit,
      activityTitle: activityTitle,
    );
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
        throw const FormatException(
          'Saved TP diagnostic entry fields are invalid.',
        );
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
