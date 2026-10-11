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
      try {
        final Map<String, dynamic> data =
            Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
        final int id = data['requestId']! as int;
        final Completer<R6NetworkOutcome>? completer = _pending.remove(id);
        if (completer == null) return;
        if (data['error'] is String) {
          completer.completeError(StateError(data['error']! as String));
        } else {
          completer.complete(R6NetworkOutcome.fromJson(
            Map<String, dynamic>.from(data['result']! as Map),
          ));
        }
      } catch (error, stack) {
        final Completer<R6NetworkOutcome>? active = _pending.values
            .isEmpty ? null : _pending.values.first;
        _pending.clear();
        active?.completeError(error, stack);
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
  late final StreamSubscription<html.ErrorEvent> _errorListener;
  bool _closed = false;

  @override
  Future<R6NetworkOutcome> solve(R6NetworkJob job) async {
    if (_closed || _pending.isNotEmpty) {
      throw StateError('R6/N Web Worker closed or already busy');
    }
    final Completer<R6NetworkOutcome> completer =
        Completer<R6NetworkOutcome>();
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
