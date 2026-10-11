import 'dart:async';
import 'dart:isolate';

import 'r6n_network_job.dart';
import 'r6n_worker.dart';

final class NativeR6Worker implements R6Worker {
  NativeR6Worker._();

  final ReceivePort _messages = ReceivePort();
  final Completer<SendPort> _ready = Completer<SendPort>();
  final Map<int, Completer<R6NetworkOutcome>> _pending =
      <int, Completer<R6NetworkOutcome>>{};
  Isolate? _isolate;
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;

  static Future<NativeR6Worker> start() async {
    final NativeR6Worker worker = NativeR6Worker._();
    worker._subscription = worker._messages.listen(worker._onMessage);
    try {
      worker._isolate = await Isolate.spawn<SendPort>(
        _workerMain,
        worker._messages.sendPort,
      );
      await worker._ready.future;
      return worker;
    } catch (_) {
      await worker.close();
      rethrow;
    }
  }

  void _onMessage(dynamic message) {
    if (message is SendPort) {
      if (!_ready.isCompleted) _ready.complete(message);
      return;
    }
    if (message is! Map) return;
    final Map<String, dynamic> data = Map<String, dynamic>.from(message);
    final Object? id = data['requestId'];
    if (id is! int) return;
    final Completer<R6NetworkOutcome>? pending = _pending.remove(id);
    if (pending == null) return;
    if (data['error'] is String) {
      pending.completeError(StateError(data['error']! as String));
      return;
    }
    try {
      final R6NetworkOutcome result = R6NetworkOutcome.fromJson(
        Map<String, dynamic>.from(data['result']! as Map),
      );
      pending.complete(result);
    } catch (error, stack) {
      pending.completeError(error, stack);
    }
  }

  @override
  Future<R6NetworkOutcome> solve(R6NetworkJob request) async {
    if (_closed || _pending.isNotEmpty) {
      throw StateError('R6/N worker closed or request already active');
    }
    final Completer<R6NetworkOutcome> response =
        Completer<R6NetworkOutcome>();
    _pending[request.requestId] = response;
    final SendPort send = await _ready.future;
    if (_closed) throw StateError('R6/N worker closed');
    send.send(request.toJson());
    final R6NetworkOutcome result = await response.future;
    if (result.requestId != request.requestId ||
        result.projectRevision != request.projectRevision ||
        result.engineVersion != request.engineVersion) {
      throw StateError('Stale or foreign worker response rejected');
    }
    return result;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final Completer<R6NetworkOutcome> item in _pending.values) {
      item.completeError(StateError('R6/N worker closed'));
    }
    _pending.clear();
    _isolate?.kill(priority: Isolate.immediate);
    await _subscription?.cancel();
    _messages.close();
  }

  static void _workerMain(SendPort parent) {
    final ReceivePort incoming = ReceivePort();
    parent.send(incoming.sendPort);
    incoming.listen((dynamic message) {
      if (message is! Map) return;
      final Map<String, dynamic> data = Map<String, dynamic>.from(message);
      final Object? id = data['requestId'];
      try {
        final R6NetworkJob job = R6NetworkJob.fromJson(data);
        parent.send(<String, Object?>{
          'requestId': id,
          'result': job.execute().toJson(),
        });
      } catch (error) {
        parent.send(<String, Object?>{
          'requestId': id,
          'error': error.toString(),
        });
      }
    });
  }
}

Future<R6Worker> createR6Worker() => NativeR6Worker.start();
