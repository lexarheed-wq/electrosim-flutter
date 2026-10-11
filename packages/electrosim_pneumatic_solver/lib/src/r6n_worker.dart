import 'r6n_network_job.dart';
import 'r6n_worker_stub.dart'
    if (dart.library.io) 'r6n_worker_native.dart'
    if (dart.library.html) 'r6n_worker_web.dart' as implementation;

abstract interface class R6Worker {
  Future<R6NetworkOutcome> solve(R6NetworkJob request);
  Future<void> close();
}

/// The native implementation uses a persistent Dart isolate; the browser
/// uses a real dedicated Web Worker running dart2js canonical physics.
Future<R6Worker> createR6Worker() => implementation.createR6Worker();
