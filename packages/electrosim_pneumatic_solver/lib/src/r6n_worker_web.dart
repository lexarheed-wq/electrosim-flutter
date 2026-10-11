import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

import 'r6n_network_job.dart';
import 'r6n_worker.dart';

/// Worker URL is emitted by dart compile js before flutter build web.
final class WebR6Worker implements R6Worker {
  WebR6Worker._(this._worker) {
    _listener = _worker.onMessage.listen((html.MessageEvent event) {
      final dynamic raw = event.data;
      Completer<R6NetworkOutcome>? response;
      try {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          jsonDecode(raw as String) as Map,
        );
        final int id = data['requestId']! as int;
        response = _pending.remove(id);
        if (response == null) return;
        if (data['error'] is String) {
          response.completeError(StateError(data['error']! as String));
        } else {
          // Parse before settling: a malformed payload must never strand
          // the already-removed request completer.
          final R6NetworkOutcome outcome = R6NetworkOutcome.fromJson(
            Map<String, dynamic>.from(data['result']! as Map),
          );
          response.complete(outcome);
        }
      } catch (error, stack) {
        if (response != null && !response.isCompleted) {
          response.completeError(error, stack);
        } else {
          // If the reply cannot be correlated, fail the active request
          // rather than waiting indefinitely for a missing request ID.
          for (final Completer<R6NetworkOutcome> pending in _pending.values) {
            pending.completeError(error, stack);
          }
          _pending.clear();
        }
      }
    });
    _errorListener = _worker.onError.listen((_) {
      for (final Completer<R6NetworkOutcome> item in _pending.values) {
        item.completeError(StateError('Dedicated Web Worker failed'));
      }
      _pending.clear();
    });
  }

  final html.Worker _worker;
  final Map<int, Completer<R6NetworkOutcome>> _pending =
      <int, Completer<R6NetworkOutcome>>{};
  late final StreamSubscription<html.MessageEvent> _listener;
  late final StreamSubscription<html.Event> _errorListener;
  bool _closed = false;

  @override
  Future<R6NetworkOutcome> solve(R6NetworkJob job) async {
    if (_closed || _pending.isNotEmpty) {
      throw StateError('R6/N Web Worker closed or already busy');
    }
    final Completer<R6NetworkOutcome> completer = Completer<R6NetworkOutcome>();
    _pending[job.requestId] = completer;
    _worker.postMessage(jsonEncode(job.toJson()));
    final R6NetworkOutcome result = await completer.future;
    if (result.requestId != job.requestId ||
        result.projectRevision != job.projectRevision ||
        result.engineVersion != job.engineVersion) {
      throw StateError('Stale Web Worker completion');
    }
    return result;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final Completer<R6NetworkOutcome> item in _pending.values) {
      item.completeError(StateError('R6/N Web Worker closed'));
    }
    _pending.clear();
    await _listener.cancel();
    await _errorListener.cancel();
    _worker.terminate();
  }
}

Future<R6Worker> createR6Worker() async =>
    WebR6Worker._(html.Worker('r6n_worker.dart.js'));
