import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';

import 'electrosim_runtime_engine.dart';
import 'package:flutter/foundation.dart';

final class ElectroSimTpSessionController extends ChangeNotifier {
  ElectroSimTpSessionController({
    QualifiedCatalog? catalog,
    FaultScenarioRepository? faultScenarios,
    this.tpIdValue = 'TP-RD-F17',
    this.title = 'Recherche de dérangement',
    String? scenarioId,
  }) : _faultScenarios = faultScenarios ??
           (catalog == null
               ? buildV2ProductFaultRepository()
               : FaultScenarioRepository(scenarios: catalog.faultScenarios)),
       _scenarioId = FaultScenarioId(
         scenarioId ??
             (catalog == null
                 ? 'V2-FAULT-DC-LAMP-OPEN-01'
                 : 'FAULT-DC-003'),
       ) {
    _engine = _buildEngine();
    _activeTpIdValue = tpIdValue;
  }

  /// Product TP flows use native V2 faults; legacy fixtures need explicit injection.
  final FaultScenarioRepository _faultScenarios;
  final String tpIdValue;
  final String title;
  final FaultScenarioId _scenarioId;
  late TpEngine _engine;
  late String _activeTpIdValue;
  int _nextActivityOrdinal = 1;
  final List<Map<String, Object?>> _teacherArchive = <Map<String, Object?>>[];

  /// Completed activities remain available for independent teacher review.
  List<Map<String, Object?>> get teacherArchive =>
      List<Map<String, Object?>>.unmodifiable(_teacherArchive);

  void deleteArchivedActivity(String id) {
    _teacherArchive.removeWhere((entry) => entry['tpId'] == id);
    notifyListeners();
  }

  TpEngine _buildEngine() => TpEngine(
    faultScenarios: _faultScenarios,
    verification: VerificationEngine(qualifiedSolve: _unifiedSolve),
  );

  static bool _unifiedSolve(CircuitState circuit) {
    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);
    return switch (circuit.mode) {
      ElectricalMode.dc =>
        snapshot.dcResult?.status == DcSolveStatus.solved,
      ElectricalMode.ac1 => snapshot.ac1Result?.isSolved ?? false,
      ElectricalMode.ac3 => snapshot.ac3Result?.isSolved ?? false,
      ElectricalMode.pv => snapshot.pvResult?.isSolved ?? false,
    };
  }

  TpId get tpId => TpId(_activeTpIdValue);

  String get defaultFaultScenarioId => _scenarioId.value;
  List<FaultScenarioDefinition> get availableFaultScenarios =>
      _faultScenarios.all;

  TpSession? _session;
  TpSession? get session => _session;

  bool get hasSession => _session != null;
  TpLifecycle? get lifecycle => _session?.lifecycle;
  bool get readOnly => _session?.readOnly ?? false;

  ElectroSimTpSessionController createStudentReplica({
    bool includeDraft = false,
  }) {
    final ElectroSimTpSessionController replica = ElectroSimTpSessionController(
      faultScenarios: _faultScenarios,
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
    CircuitState? studentStarterCircuit,
    String? activityTitle,
    String? troubleshootingScenarioId,
  }) {
    if (_session != null) {
      throw StateError('A TP session already exists.');
    }
    if (_nextActivityOrdinal > 1) {
      _activeTpIdValue = '$tpIdValue-${_nextActivityOrdinal.toString().padLeft(3, '0')}';
    }
    if (mode == TpMode.wiring &&
        (wiringReferenceCircuit == null &&
            studentStarterCircuit == null ||
            wiringReferenceCircuit != null &&
            (wiringReferenceCircuit.sources.isEmpty ||
                wiringReferenceCircuit.components.isEmpty ||
                wiringReferenceCircuit.connections.isEmpty))) {
      throw StateError(
        'Préparez un montage de référence câblé ou choisissez un schéma V2.',
      );
    }
    final TpDefinition definition = switch (mode) {
      TpMode.wiring => TpDefinition.wiring(
        id: tpId,
        title: activityTitle ?? 'TP de câblage',
        referenceCircuit: wiringReferenceCircuit,
        studentStarterCircuit: studentStarterCircuit,
      ),
      TpMode.troubleshooting => TpDefinition.troubleshooting(
        id: tpId,
        title: activityTitle ?? title,
        scenarioId: troubleshootingScenarioId == null
            ? _scenarioId
            : FaultScenarioId(troubleshootingScenarioId),
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
    if (current.lifecycle == TpLifecycle.closed) {
      final archived = <String, Object?>{...toPersistenceJson()};
      archived.remove('archive');
      archived.remove('nextActivityOrdinal');
      _teacherArchive.add(archived);
    }
    _nextActivityOrdinal++;
    _activeTpIdValue = '$tpIdValue-${_nextActivityOrdinal.toString().padLeft(3, '0')}';
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
      return <String, Object?>{
        'hasSession': false,
        'nextActivityOrdinal': _nextActivityOrdinal,
        'archive': _teacherArchive,
      };
    }
    return <String, Object?>{
      'nextActivityOrdinal': _nextActivityOrdinal,
      'archive': _teacherArchive,
      'hasSession': true,
      'tpId': _activeTpIdValue,
      'title': title,
      'scenarioId': current.definition.faultScenarioId?.value ??
          _scenarioId.value,
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

  /// Browser-safe lifecycle snapshot: the teacher's reference wiring must
  /// never leave the authoritative host, including before evaluation.
  Map<String, Object?> toStudentPersistenceJson() {
    final json = <String, Object?>{...toPersistenceJson()};
    json.remove('referenceCircuit');
    json.remove('archive');
    json.remove('nextActivityOrdinal');
    if (_session?.lifecycle != TpLifecycle.evaluated &&
        _session?.lifecycle != TpLifecycle.closed) {
      json.remove('teacherScore');
    }
    return json;
  }

  /// Restores a TP session by replaying validated TpEngine transitions.
  ///
  /// Replaying transitions instead of injecting private engine state keeps all
  /// lifecycle and verification invariants active during recovery.
  void restoreFromPersistenceJson(Map<String, Object?> json) {
    _engine = _buildEngine();
    _session = null;
    _teacherArchive.clear();
    final Object? archiveRaw = json['archive'];
    if (archiveRaw is List) {
      for (final Object? entry in archiveRaw) {
        if (entry is Map<String, dynamic> &&
            entry['tpId'] is String &&
            entry['lifecycle'] == TpLifecycle.closed.name) {
          _teacherArchive.add(<String, Object?>{...entry});
        }
      }
    }
    final Object? ordinalRaw = json['nextActivityOrdinal'];
    if (ordinalRaw is int && ordinalRaw >= 1 && ordinalRaw <= 1000000) {
      _nextActivityOrdinal = ordinalRaw;
    }
    _activeTpIdValue = tpIdValue;
    if (json['hasSession'] != true) {
      notifyListeners();
      return;
    }
    final Object? recoveredId = json['tpId'];
    final bool permittedId = recoveredId is String &&
        (recoveredId == tpIdValue ||
            (recoveredId.startsWith('$tpIdValue-') &&
                RegExp(r'^[0-9]{3,7}$').hasMatch(
                  recoveredId.substring(tpIdValue.length + 1),
                )));
    if (!permittedId || json['title'] != title) {
      throw const FormatException(
        'Saved TP identity does not match this controller.',
      );
    }

    _activeTpIdValue = recoveredId;

    final Object? selectedScenarioRaw = json['scenarioId'];
    if (selectedScenarioRaw is! String ||
        !_faultScenarios.all.any((scenario) =>
            scenario.id.value == selectedScenarioRaw)) {
      throw const FormatException('Unknown or missing TP scenario.');
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
      final Object? referenceRaw = json['referenceCircuit'];
      if (referenceRaw != null) {
        if (referenceRaw is! Map<String, dynamic>) {
          throw const FormatException('Wiring TP reference circuit is invalid.');
        }
        referenceCircuit = CircuitState.fromJson(referenceRaw);
      }
    }
    createDraft(
      mode: mode,
      wiringReferenceCircuit: referenceCircuit,
      studentStarterCircuit: mode == TpMode.wiring
          ? CircuitState.fromJson(json['studentCircuit'] as Map<String, dynamic>)
          : null,
      activityTitle: activityTitle,
      troubleshootingScenarioId: selectedScenarioRaw,
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
