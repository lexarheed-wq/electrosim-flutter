import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';

import 'tp_models.dart';
import 'verification_engine.dart';

final class TpEngine {
  TpEngine({
    required FaultScenarioRepository faultScenarios,
    VerificationEngine verification = const VerificationEngine(),
  }) : _faultScenarios = faultScenarios,
       _verification = verification;

  final FaultScenarioRepository _faultScenarios;
  final VerificationEngine _verification;

  final Map<TpId, TpSession> _sessions = {};
  TpId? _activeTp;

  TpSession createDraft(TpDefinition definition) {
    if (_sessions.containsKey(definition.id))
      throw StateError('Duplicate TP ${definition.id.value}.');
    final circuit = switch (definition.mode) {
      TpMode.wiring => definition.referenceCircuit!,
      TpMode.troubleshooting => _scenarioFor(definition).faultyCircuit,
    };
    final session = TpSession(
      definition: definition,
      lifecycle: TpLifecycle.draft,
      studentCircuit: circuit,
      diagnosticSheet: DiagnosticSheet(),
    );
    _sessions[definition.id] = session;
    return session;
  }

  TpSession publish(TpId id) =>
      _transition(id, TpLifecycle.draft, TpLifecycle.published);

  TpSession start(TpId id) {
    if (_activeTp != null && _activeTp != id)
      throw StateError('Another TP is already active.');
    final session = _transition(id, TpLifecycle.published, TpLifecycle.started);
    _activeTp = id;
    return session;
  }

  TpSession updateCircuit(TpId id, CircuitState circuit) {
    final session = _require(id);
    if (session.lifecycle != TpLifecycle.started || session.readOnly)
      throw StateError('TP is read-only.');
    if (circuit.circuitId != session.studentCircuit.circuitId)
      throw StateError('Circuit identity mismatch.');
    final next = TpSession(
      definition: session.definition,
      lifecycle: session.lifecycle,
      studentCircuit: circuit,
      diagnosticSheet: session.diagnosticSheet,
    );
    _sessions[id] = next;
    return next;
  }

  TpSession addDiagnosticEntry(TpId id, DiagnosticEntry entry) {
    final session = _require(id);
    if (!session.diagnosticSheetVisibleFor(TpRole.student)) {
      throw StateError(
        'Diagnostic sheet is only available to a student during troubleshooting.',
      );
    }
    final next = TpSession(
      definition: session.definition,
      lifecycle: session.lifecycle,
      studentCircuit: session.studentCircuit,
      diagnosticSheet: session.diagnosticSheet.add(entry),
    );
    _sessions[id] = next;
    return next;
  }

  TpSession submit(TpId id) {
    final session = _require(id);
    if (session.lifecycle != TpLifecycle.started)
      throw StateError('Only a started TP can be submitted.');
    final evaluation = switch (session.definition.mode) {
      TpMode.wiring => _verification.evaluateWiring(
        session.definition,
        session.studentCircuit,
      ),
      TpMode.troubleshooting => _verification.evaluateTroubleshooting(
        session.definition,
        session.studentCircuit,
        _scenarioFor(session.definition),
      ),
    };
    final next = TpSession(
      definition: session.definition,
      lifecycle: TpLifecycle.submitted,
      studentCircuit: session.studentCircuit,
      diagnosticSheet: session.diagnosticSheet,
      evaluation: evaluation,
    );
    _sessions[id] = next;
    _activeTp = null;
    return next;
  }

  TpSession evaluate(TpId id, {int? teacherScore}) {
    final session = _require(id);
    if (session.lifecycle != TpLifecycle.submitted) {
      throw StateError(
        'Invalid TP transition ${session.lifecycle.name} -> ${TpLifecycle.evaluated.name}.',
      );
    }
    final TpEvaluation? generated = session.evaluation;
    if (generated == null) {
      throw StateError('Submitted TP has no generated evaluation.');
    }
    final int score = teacherScore ?? generated.score;
    if (score < 0 || score > session.definition.maxScore) {
      throw RangeError.range(
        score,
        0,
        session.definition.maxScore,
        'teacherScore',
      );
    }
    final next = TpSession(
      definition: session.definition,
      lifecycle: TpLifecycle.evaluated,
      studentCircuit: session.studentCircuit,
      diagnosticSheet: session.diagnosticSheet,
      evaluation: TpEvaluation(
        score: score,
        functional: generated.functional,
        safetyOk: generated.safetyOk,
        measurementsOk: generated.measurementsOk,
      ),
    );
    _sessions[id] = next;
    return next;
  }

  TpSession close(TpId id) => _transition(
    id,
    TpLifecycle.evaluated,
    TpLifecycle.closed,
    preserveEvaluation: true,
  );

  TpSession cancel(TpId id) {
    final TpSession session = _require(id);
    if (session.lifecycle != TpLifecycle.draft &&
        session.lifecycle != TpLifecycle.published &&
        session.lifecycle != TpLifecycle.started) {
      throw StateError('Only a non-submitted TP can be cancelled.');
    }
    final TpSession next = TpSession(
      definition: session.definition,
      lifecycle: TpLifecycle.closed,
      studentCircuit: session.studentCircuit,
      diagnosticSheet: session.diagnosticSheet,
    );
    _sessions[id] = next;
    if (_activeTp == id) _activeTp = null;
    return next;
  }

  TpSession get(TpId id) => _require(id);

  TpSession _transition(
    TpId id,
    TpLifecycle from,
    TpLifecycle to, {
    bool preserveEvaluation = false,
  }) {
    final session = _require(id);
    if (session.lifecycle != from)
      throw StateError(
        'Invalid TP transition ${session.lifecycle.name} -> ${to.name}.',
      );
    final next = TpSession(
      definition: session.definition,
      lifecycle: to,
      studentCircuit: session.studentCircuit,
      diagnosticSheet: session.diagnosticSheet,
      evaluation: preserveEvaluation ? session.evaluation : null,
    );
    _sessions[id] = next;
    return next;
  }

  FaultScenarioDefinition _scenarioFor(TpDefinition definition) {
    final id = definition.faultScenarioId;
    if (id == null) throw StateError('Troubleshooting TP has no scenario.');
    final scenario = _faultScenarios.findById(id);
    if (scenario == null)
      throw StateError('Unknown fault scenario ${id.value}.');
    return scenario;
  }

  TpSession _require(TpId id) {
    final session = _sessions[id];
    if (session == null) throw StateError('Unknown TP ${id.value}.');
    return session;
  }
}
