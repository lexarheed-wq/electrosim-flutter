import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';

enum TpMode { wiring, troubleshooting }

enum TpLifecycle { draft, published, started, submitted, evaluated, closed }

enum TpRole { teacher, student }

final class TpId {
  TpId(String raw) : value = _validate(raw);
  final String value;
  static String _validate(String raw) {
    final value = raw.trim();
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{2,63}$').hasMatch(value)) {
      throw ArgumentError.value(raw, 'raw', 'Invalid TpId');
    }
    return value;
  }

  @override
  bool operator ==(Object other) => other is TpId && other.value == value;
  @override
  int get hashCode => value.hashCode;
}

final class DiagnosticEntry {
  const DiagnosticEntry({required this.promptId, required this.answer});
  final String promptId;
  final String answer;
  Map<String, Object?> toJson() => {'promptId': promptId, 'answer': answer};
}

final class DiagnosticSheet {
  DiagnosticSheet({List<DiagnosticEntry> entries = const []})
    : entries = List.unmodifiable(entries);
  final List<DiagnosticEntry> entries;
  DiagnosticSheet add(DiagnosticEntry entry) =>
      DiagnosticSheet(entries: [...entries, entry]);
  Map<String, Object?> toJson() => {
    'entries': entries.map((e) => e.toJson()).toList(growable: false),
  };
}

final class TpDefinition {
  TpDefinition.wiring({
    required this.id,
    required this.title,
    required this.referenceCircuit,
    this.studentStarterCircuit,
    this.maxScore = 100,
  }) : mode = TpMode.wiring,
       faultScenarioId = null;

  TpDefinition.troubleshooting({
    required this.id,
    required this.title,
    required FaultScenarioId scenarioId,
    this.maxScore = 100,
  }) : mode = TpMode.troubleshooting,
       faultScenarioId = scenarioId,
       referenceCircuit = null,
       studentStarterCircuit = null;

  final TpId id;
  final String title;
  final TpMode mode;
  /// Teacher-only truth. Null in an untrusted student replica.
  final CircuitState? referenceCircuit;
  /// Public blank exercise plate; never a solution assembled by the teacher.
  final CircuitState? studentStarterCircuit;
  final FaultScenarioId? faultScenarioId;
  final int maxScore;
}

final class TpEvaluation {
  const TpEvaluation({
    required this.score,
    required this.functional,
    required this.safetyOk,
    required this.measurementsOk,
  });
  final int score;
  final bool functional;
  final bool safetyOk;
  final bool measurementsOk;
  bool get passed => functional && safetyOk && measurementsOk;
}

final class TpSession {
  const TpSession({
    required this.definition,
    required this.lifecycle,
    required this.studentCircuit,
    required this.diagnosticSheet,
    this.evaluation,
  });

  final TpDefinition definition;
  final TpLifecycle lifecycle;
  final CircuitState studentCircuit;
  final DiagnosticSheet diagnosticSheet;
  final TpEvaluation? evaluation;

  bool get readOnly =>
      lifecycle == TpLifecycle.submitted ||
      lifecycle == TpLifecycle.evaluated ||
      lifecycle == TpLifecycle.closed;

  bool diagnosticSheetVisibleFor(TpRole role) =>
      role == TpRole.student &&
      definition.mode == TpMode.troubleshooting &&
      lifecycle == TpLifecycle.started;

  Map<String, Object?> payloadFor(TpRole role) {
    final payload = <String, Object?>{
      'tpId': definition.id.value,
      'title': definition.title,
      'mode': definition.mode.name,
      'lifecycle': lifecycle.name,
      'readOnly': readOnly,
      'studentCircuit': studentCircuit.toJson(),
      if (role == TpRole.student && diagnosticSheetVisibleFor(role))
        'diagnosticSheet': diagnosticSheet.toJson(),
      if (role == TpRole.teacher && evaluation != null)
        'evaluation': {
          'score': evaluation!.score,
          'functional': evaluation!.functional,
          'safetyOk': evaluation!.safetyOk,
          'measurementsOk': evaluation!.measurementsOk,
        },
    };
    return payload;
  }
}
