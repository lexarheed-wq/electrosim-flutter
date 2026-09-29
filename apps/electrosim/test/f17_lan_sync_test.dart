import 'dart:async';
import 'dart:io';

import 'package:electrosim/runtime/electrosim_lan_sync.dart';
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting for synchronized state.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

CircuitState _nextRevision(CircuitState source) => CircuitState(
      circuitId: source.circuitId,
      revision: source.revision + 1,
      mode: source.mode,
      components: source.components,
      connections: source.connections,
      sources: source.sources,
      settings: source.settings,
      metadata: source.metadata,
    );

void main() {
  group('F17-R11 LAN teacher/student synchronization', () {
    test('protocol envelope round-trips with explicit version and sequence', () {
      const ElectroSimSyncEnvelope original = ElectroSimSyncEnvelope(
        type: ElectroSimSyncMessageType.studentState,
        sessionCode: 'ABC234',
        senderId: 'student-001',
        sequence: 7,
        payload: <String, Object?>{
          'state': <String, Object?>{'hasSession': false},
        },
      );

      final ElectroSimSyncEnvelope decoded =
          ElectroSimSyncEnvelope.fromJsonString(original.toJsonString());

      expect(decoded.type, original.type);
      expect(decoded.sessionCode, original.sessionCode);
      expect(decoded.senderId, original.senderId);
      expect(decoded.sequence, 7);
      expect(decoded.payload['state'], isA<Map<String, dynamic>>());
    });

    test('teacher authority synchronizes the full TP lifecycle over WebSocket',
        () async {
      final ElectroSimTpSessionController teacher =
          ElectroSimTpSessionController();
      teacher.createDraft();
      teacher.publish();

      final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
        controller: teacher,
        sessionCode: 'ABC234',
      );
      final ElectroSimLanHostInfo info = await host.start(
        address: InternetAddress.loopbackIPv4,
      );

      final ElectroSimTpSessionController student =
          ElectroSimTpSessionController();
      final ElectroSimLanSyncClient client = ElectroSimLanSyncClient(
        controller: student,
        sessionCode: 'ABC234',
        clientId: 'student-001',
        autoReconnect: false,
      );

      addTearDown(client.close);
      addTearDown(host.close);

      await client.connect(info.preferredEndpoint);
      expect(client.synchronized, isTrue);
      expect(student.lifecycle, TpLifecycle.published);

      student.startStudent();
      await _waitFor(() => teacher.lifecycle == TpLifecycle.started);

      final CircuitState edited = _nextRevision(student.studentCircuit!);
      student.updateStudentCircuit(edited);
      student.addDiagnosticEntry(
        promptId: 'symptom',
        answer: 'La lampe reste éteinte.',
      );

      await _waitFor(
        () =>
            teacher.studentCircuit?.revision == edited.revision &&
            teacher.session!.diagnosticSheet.entries.length == 1,
      );
      expect(
        teacher.session!.diagnosticSheet.entries.single.answer,
        'La lampe reste éteinte.',
      );

      student.submitStudent();
      await _waitFor(() => teacher.lifecycle == TpLifecycle.submitted);
      expect(teacher.readOnly, isTrue);

      teacher.evaluateTeacher(score: 81);
      await _waitFor(
        () =>
            student.lifecycle == TpLifecycle.evaluated &&
            student.evaluation?.score == 81,
      );
      expect(student.readOnly, isTrue);

      teacher.closeTeacher();
      await _waitFor(() => student.lifecycle == TpLifecycle.closed);
      expect(student.readOnly, isTrue);
    });

    test('student cannot inject teacher evaluation or score', () async {
      final ElectroSimTpSessionController teacher =
          ElectroSimTpSessionController();
      teacher.createDraft();
      teacher.publish();

      final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
        controller: teacher,
        sessionCode: 'SAFE24',
      );
      final ElectroSimLanHostInfo info = await host.start(
        address: InternetAddress.loopbackIPv4,
      );
      final ElectroSimTpSessionController student =
          ElectroSimTpSessionController();
      final ElectroSimLanSyncClient client = ElectroSimLanSyncClient(
        controller: student,
        sessionCode: 'SAFE24',
        clientId: 'student-safe',
        autoReconnect: false,
      );

      addTearDown(client.close);
      addTearDown(host.close);

      await client.connect(info.preferredEndpoint);
      student.startStudent();
      await _waitFor(() => teacher.lifecycle == TpLifecycle.started);
      student.submitStudent();
      await _waitFor(() => teacher.lifecycle == TpLifecycle.submitted);

      student.evaluateTeacher(score: 100);

      await _waitFor(
        () =>
            client.lastError != null &&
            student.lifecycle == TpLifecycle.submitted,
      );
      expect(teacher.lifecycle, TpLifecycle.submitted);
      expect(teacher.evaluation?.score, isNot(100));
    });

    test('manual reconnect catches up to the latest authoritative teacher state',
        () async {
      final ElectroSimTpSessionController teacher =
          ElectroSimTpSessionController();
      teacher.createDraft();
      teacher.publish();

      final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
        controller: teacher,
        sessionCode: 'RECON2',
      );
      final ElectroSimLanHostInfo info = await host.start(
        address: InternetAddress.loopbackIPv4,
      );
      final ElectroSimTpSessionController student =
          ElectroSimTpSessionController();
      final ElectroSimLanSyncClient client = ElectroSimLanSyncClient(
        controller: student,
        sessionCode: 'RECON2',
        clientId: 'student-reconnect',
        autoReconnect: false,
      );

      addTearDown(client.close);
      addTearDown(host.close);

      await client.connect(info.preferredEndpoint);
      student.startStudent();
      await _waitFor(() => teacher.lifecycle == TpLifecycle.started);
      student.submitStudent();
      await _waitFor(() => teacher.lifecycle == TpLifecycle.submitted);

      await client.disconnect();
      expect(client.status, ElectroSimLanSyncStatus.disconnected);
      expect(student.lifecycle, TpLifecycle.submitted);

      teacher.evaluateTeacher(score: 73);
      expect(teacher.lifecycle, TpLifecycle.evaluated);
      expect(student.lifecycle, TpLifecycle.submitted);

      await client.reconnect();
      expect(client.synchronized, isTrue);
      expect(student.lifecycle, TpLifecycle.evaluated);
      expect(student.evaluation?.score, 73);
    });

    test('wrong session code is rejected before synchronization', () async {
      final ElectroSimTpSessionController teacher =
          ElectroSimTpSessionController();
      final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
        controller: teacher,
        sessionCode: 'RIGHT2',
      );
      final ElectroSimLanHostInfo info = await host.start(
        address: InternetAddress.loopbackIPv4,
      );

      final ElectroSimLanSyncClient client = ElectroSimLanSyncClient(
        controller: ElectroSimTpSessionController(),
        sessionCode: 'WRONG2',
        clientId: 'student-wrong',
        autoReconnect: false,
      );
      addTearDown(client.close);
      addTearDown(host.close);

      await expectLater(
        client.connect(
          info.preferredEndpoint,
          timeout: const Duration(seconds: 2),
        ),
        throwsA(anything),
      );
      expect(client.synchronized, isFalse);
    });
  });
}
