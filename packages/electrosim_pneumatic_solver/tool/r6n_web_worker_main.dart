import 'dart:convert';
import 'dart:html' as html;

import 'package:electrosim_pneumatic_solver/src/r6n_network_job.dart';

/// Dart-to-JavaScript compiled worker entry; same engine as native isolate.
void main() {
  final html.DedicatedWorkerGlobalScope scope =
      html.DedicatedWorkerGlobalScope.instance;
  scope.onMessage.listen((html.MessageEvent event) {
    int? id;
    try {
      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        jsonDecode(event.data as String) as Map,
      );
      id = payload['requestId'] as int?;
      final R6NetworkJob job = R6NetworkJob.fromJson(payload);
      scope.postMessage(
        jsonEncode(<String, Object?>{
          'requestId': id,
          'result': job.execute().toJson(),
        }),
      );
    } catch (error) {
      scope.postMessage(
        jsonEncode(<String, Object?>{
          'requestId': id,
          'error': error.toString(),
        }),
      );
    }
  });
}
