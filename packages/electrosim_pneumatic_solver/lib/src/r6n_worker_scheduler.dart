import 'dart:async';

import 'r6n_network_job.dart';
import 'r6n_worker.dart';

/// Bounded queue shared by the real native isolate and Web Worker adapters.
/// Only one calculation runs; the most recent pending edit supersedes older
/// pending edits. An obsolete answer is rejected, never shown by the UI.
final class R6WorkerScheduler {
  R6WorkerScheduler(
    this.worker, {
    required this.engineVersion,
    this.requestTimeout = const Duration(seconds: 30),
  }) {
    if (requestTimeout <= Duration.zero) {
      throw ArgumentError.value(
        requestTimeout,
        'requestTimeout',
        'Must be positive',
      );
    }
  }

  final R6Worker worker;
  final String engineVersion;

  /// Upper bound on a single solver response, independent of the UI clock.
  /// A timeout closes the transport rather than reusing an unresponsive worker.
  final Duration requestTimeout;
  int _revision = 0;
  int _nextRequestId = 0;
  bool _closed = false;
  _QueuedCalculation? _active;
  _QueuedCalculation? _pending;

  int get revision => _revision;
  bool get isBusy => _active != null;
  bool get hasPending => _pending != null;

  void changeRevision() {
    _ensureOpen();
    _revision++;
    final _QueuedCalculation? pending = _pending;
    _pending = null;
    pending?.reject(StateError('Queued calculation superseded by revision'));
  }

  Future<R6NetworkOutcome> submit({
    required R6NetworkJob Function(int revision, int requestId) build,
  }) {
    _ensureOpen();
    final R6NetworkJob job = build(_revision, ++_nextRequestId);
    if (job.projectRevision != _revision ||
        job.requestId != _nextRequestId ||
        job.engineVersion != engineVersion) {
      throw StateError('Solver request revision or engine version mismatch');
    }
    final _QueuedCalculation calculation = _QueuedCalculation(job);
    if (_active == null) {
      _run(calculation);
    } else {
      _pending?.reject(StateError('Superseded by latest project update'));
      _pending = calculation;
    }
    return calculation.result.future;
  }

  void _run(_QueuedCalculation calculation) {
    _active = calculation;
    Future<void>(() async {
      try {
        if (_closed) throw StateError('Solver session closed');
        final R6NetworkOutcome answer = await worker
            .solve(calculation.job)
            .timeout(requestTimeout);
        if (_closed ||
            calculation.job.projectRevision != _revision ||
            answer.projectRevision != calculation.job.projectRevision ||
            answer.requestId != calculation.job.requestId ||
            answer.engineVersion != engineVersion) {
          calculation.reject(StateError('Stale or foreign solver result'));
        } else {
          _validatePhysicalOutcome(calculation.job, answer);
          calculation.accept(answer);
        }
      } on TimeoutException catch (error, stack) {
        // Failing closed prevents a wedged worker from blocking all subsequent
        // edits or silently applying its eventual stale response.
        calculation.reject(
          StateError('R6/N solver exceeded request timeout: $requestTimeout'),
          stack,
        );
        try {
          await close();
        } catch (_) {
          // The request has already been rejected; the session stays closed.
          // Transport teardown errors must not turn timeout into a success.
        }
      } catch (error, stack) {
        calculation.reject(error, stack);
      } finally {
        _active = null;
        final _QueuedCalculation? next = _pending;
        _pending = null;
        if (!_closed && next != null) {
          if (next.job.projectRevision == _revision) {
            _run(next);
          } else {
            next.reject(StateError('Revision changed before dispatch'));
          }
        }
      }
    });
  }

  // Worker IDs alone do not authenticate physical correctness. A worker
  // response is never promoted to the accepted UI snapshot unless it
  // conserves mass and preserves the fixed-chamber topology and clock.
  static void _validatePhysicalOutcome(
    R6NetworkJob job,
    R6NetworkOutcome answer,
  ) {
    final snapshot = answer.snapshot;
    final expectedTime = job.before.timeS + job.durationS;
    final timeTolerance = 1e-12 * (1 + expectedTime.abs());
    if (!snapshot.timeS.isFinite ||
        (snapshot.timeS - expectedTime).abs() > timeTolerance ||
        snapshot.acceptedSubsteps < job.before.acceptedSubsteps ||
        (job.durationS > 0 &&
            snapshot.acceptedSubsteps <= job.before.acceptedSubsteps)) {
      throw StateError('R6/N worker returned an inconsistent physical clock');
    }

    final expectedChambers = job.before.chambers;
    if (snapshot.chambers.length != expectedChambers.length ||
        !snapshot.chambers.keys.toSet().containsAll(expectedChambers.keys)) {
      throw StateError('R6/N worker changed the physical topology');
    }
    for (final entry in expectedChambers.entries) {
      final before = entry.value;
      final after = snapshot.chambers[entry.key]!;
      if (after.id != entry.key ||
          after.volumeM3 != before.volumeM3 ||
          after.temperatureK != before.temperatureK ||
          !after.massKg.isFinite ||
          after.massKg <= 0) {
        throw StateError('R6/N worker returned an invalid chamber state');
      }
    }

    final expectedPassages = job.network.passages
        .map((passage) => passage.id)
        .toSet();
    if (snapshot.passageMassFlowKgPerS.length != expectedPassages.length ||
        !snapshot.passageMassFlowKgPerS.keys.toSet().containsAll(
          expectedPassages,
        ) ||
        snapshot.passageMassFlowKgPerS.values.any((flow) => !flow.isFinite)) {
      throw StateError('R6/N worker returned invalid passage flows');
    }

    final massResidual =
        snapshot.totalMassKg -
        job.before.totalMassKg -
        (snapshot.externalMassAddedKg - job.before.externalMassAddedKg);
    if (!massResidual.isFinite || massResidual.abs() > 1e-9) {
      throw StateError('R6/N worker violated the air mass balance');
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pending?.reject(StateError('Solver session closed'));
    _pending = null;
    _active?.reject(StateError('Solver session closed'));
    await worker.close();
  }

  void _ensureOpen() {
    if (_closed) throw StateError('Solver session closed');
  }
}

final class _QueuedCalculation {
  _QueuedCalculation(this.job);
  final R6NetworkJob job;
  final Completer<R6NetworkOutcome> result = Completer<R6NetworkOutcome>();

  void reject(Object error, [StackTrace? stack]) {
    if (!result.isCompleted) result.completeError(error, stack);
  }

  void accept(R6NetworkOutcome value) {
    if (!result.isCompleted) result.complete(value);
  }
}
