import 'dart:async';

import 'r6n_network_job.dart';
import 'r6n_worker.dart';

/// Bounded queue shared by the real native isolate and Web Worker adapters.
/// Only one calculation runs; the most recent pending edit supersedes older
/// pending edits. An obsolete answer is rejected, never shown by the UI.
final class R6WorkerScheduler {
  R6WorkerScheduler(this.worker, {required this.engineVersion});

  final R6Worker worker;
  final String engineVersion;
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
        final R6NetworkOutcome answer = await worker.solve(calculation.job);
        if (_closed ||
            calculation.job.projectRevision != _revision ||
            answer.projectRevision != calculation.job.projectRevision ||
            answer.requestId != calculation.job.requestId ||
            answer.engineVersion != engineVersion) {
          calculation.reject(StateError('Stale or foreign solver result'));
        } else {
          calculation.accept(answer);
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
