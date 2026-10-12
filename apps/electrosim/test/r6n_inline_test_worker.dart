import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

/// Deterministic unit/widget-test double only. Production workshop always
/// creates a native isolate or dedicated browser worker. The real transport
/// has its own end-to-end Flutter test in r6n_workshop_worker_integration_test.
final class InlineCanonicalTestWorker implements R6Worker {
  bool _closed = false;

  @override
  Future<R6NetworkOutcome> solve(R6NetworkJob request) async {
    if (_closed) throw StateError('Test worker is closed');
    return request.execute();
  }

  @override
  Future<void> close() async {
    _closed = true;
  }
}

Future<R6Worker> createInlineCanonicalTestWorker() async =>
    InlineCanonicalTestWorker();
