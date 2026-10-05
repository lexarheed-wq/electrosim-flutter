import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:electrosim/main.dart' as app;
import 'package:electrosim/runtime/electrosim_lan_sync.dart';
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
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

Future<void> _ensureTopOpen(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimTopRegionKey);
  if (region.evaluate().isEmpty || tester.getRect(region).bottom <= 0) {
    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final Stopwatch stopwatch = Stopwatch()..start();
  while (finder.evaluate().isEmpty) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting for widget: $finder');
    }
    await tester.pump(const Duration(milliseconds: 20));
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
    test(
      'protocol envelope round-trips with explicit version and sequence',
      () {
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
      },
    );

    test(
      'teacher authority synchronizes the full TP lifecycle over WebSocket',
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

        teacher.startTeacher();
        await _waitFor(() => student.lifecycle == TpLifecycle.started);

        final CircuitState edited = _nextRevision(student.studentCircuit!);
        student.updateStudentCircuit(edited);
        student.addDiagnosticEntry(
          promptId: 'symptom',
          answer: 'La lampe reste éteinte.',
        );

        await _waitFor(
          () =>
              host.studentSessions['student-001']?.studentCircuit.revision ==
                  edited.revision &&
              host
                      .studentSessions['student-001']!
                      .diagnosticSheet
                      .entries
                      .length ==
                  1,
        );
        expect(
          host
              .studentSessions['student-001']!
              .diagnosticSheet
              .entries
              .single
              .answer,
          'La lampe reste éteinte.',
        );
        expect(teacher.lifecycle, TpLifecycle.started);

        student.submitStudent();
        await _waitFor(
          () =>
              host.studentSessions['student-001']?.lifecycle ==
              TpLifecycle.submitted,
        );
        expect(teacher.lifecycle, TpLifecycle.started);

        host.evaluateStudent('student-001', score: 81);
        await _waitFor(
          () =>
              student.lifecycle == TpLifecycle.evaluated &&
              student.evaluation?.score == 81,
        );
        expect(student.readOnly, isTrue);

        host.closeClassroomSession();
        await _waitFor(() => student.lifecycle == TpLifecycle.closed);
        expect(student.readOnly, isTrue);
        expect(teacher.lifecycle, TpLifecycle.closed);
      },
    );

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
      teacher.startTeacher();
      await _waitFor(() => student.lifecycle == TpLifecycle.started);
      student.submitStudent();
      await _waitFor(
        () =>
            host.studentSessions['student-safe']?.lifecycle ==
            TpLifecycle.submitted,
      );
      expect(teacher.lifecycle, TpLifecycle.started);
      final int authoritativeScore =
          host.studentSessions['student-safe']!.evaluation!.score;

      student.evaluateTeacher(score: 100);

      await _waitFor(
        () =>
            client.lastError != null &&
            student.lifecycle == TpLifecycle.submitted,
      );
      expect(teacher.lifecycle, TpLifecycle.started);
      expect(
        host.studentSessions['student-safe']?.lifecycle,
        TpLifecycle.submitted,
      );
      expect(
        host.studentSessions['student-safe']?.evaluation?.score,
        authoritativeScore,
      );
    });

    test(
      'manual reconnect catches up to the latest authoritative teacher state',
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
        teacher.startTeacher();
        await _waitFor(() => student.lifecycle == TpLifecycle.started);
        student.submitStudent();
        await _waitFor(
          () =>
              host.studentSessions['student-reconnect']?.lifecycle ==
              TpLifecycle.submitted,
        );

        await client.disconnect();
        expect(client.status, ElectroSimLanSyncStatus.disconnected);
        expect(student.lifecycle, TpLifecycle.submitted);

        host.evaluateStudent('student-reconnect', score: 73);
        expect(
          host.studentSessions['student-reconnect']?.lifecycle,
          TpLifecycle.evaluated,
        );
        expect(student.lifecycle, TpLifecycle.submitted);

        await client.reconnect();
        expect(client.synchronized, isTrue);
        expect(student.lifecycle, TpLifecycle.evaluated);
        expect(student.evaluation?.score, 73);
      },
    );

    test(
      'two LAN students keep independent circuit and submission state',
      () async {
        final ElectroSimTpSessionController teacher =
            ElectroSimTpSessionController();
        teacher.createDraft();
        teacher.publish();

        final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
          controller: teacher,
          sessionCode: 'CLASS2',
        );
        final ElectroSimLanHostInfo info = await host.start(
          address: InternetAddress.loopbackIPv4,
        );

        final ElectroSimTpSessionController a = ElectroSimTpSessionController();
        final ElectroSimTpSessionController b = ElectroSimTpSessionController();
        final ElectroSimLanSyncClient clientA = ElectroSimLanSyncClient(
          controller: a,
          sessionCode: 'CLASS2',
          clientId: 'student-a',
          autoReconnect: false,
        );
        final ElectroSimLanSyncClient clientB = ElectroSimLanSyncClient(
          controller: b,
          sessionCode: 'CLASS2',
          clientId: 'student-b',
          autoReconnect: false,
        );

        addTearDown(clientA.close);
        addTearDown(clientB.close);
        addTearDown(host.close);

        await clientA.connect(info.preferredEndpoint);
        await clientB.connect(info.preferredEndpoint);
        expect(host.connectedClientIds, <String>['student-a', 'student-b']);

        teacher.startTeacher();
        await _waitFor(
          () =>
              a.lifecycle == TpLifecycle.started &&
              b.lifecycle == TpLifecycle.started,
        );

        final int bRevision = b.studentCircuit!.revision;
        final CircuitState editedA = _nextRevision(a.studentCircuit!);
        a.updateStudentCircuit(editedA);
        a.addDiagnosticEntry(promptId: 'a', answer: 'A only');

        await _waitFor(
          () =>
              host.studentSessions['student-a']?.studentCircuit.revision ==
              editedA.revision,
        );
        expect(
          host.studentSessions['student-b']?.studentCircuit.revision,
          bRevision,
        );
        expect(
          host.studentSessions['student-b']?.diagnosticSheet.entries,
          isEmpty,
        );

        a.submitStudent();
        await _waitFor(
          () =>
              host.studentSessions['student-a']?.lifecycle ==
              TpLifecycle.submitted,
        );
        expect(
          host.studentSessions['student-b']?.lifecycle,
          TpLifecycle.started,
        );
        expect(teacher.lifecycle, TpLifecycle.started);
      },
    );

    testWidgets(
      'teacher can expose a LAN code and endpoint from session management',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1100, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: app.F9WorkspaceDemoPage(sessionNavigation: true),
          ),
        );
        await tester.pumpAndSettle();

        await _ensureTopOpen(tester);
        await tester.tap(find.byKey(const Key('session-manage-action')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tp-network-share')), findsOneWidget);

        await tester.tap(find.byKey(const Key('tp-network-share')));
        await tester.pump();
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pumpAndSettle();
        await _pumpUntil(tester, find.byKey(const Key('tp-network-code')));

        expect(find.byKey(const Key('tp-network-code')), findsOneWidget);
        expect(find.byKey(const Key('tp-network-endpoint')), findsOneWidget);
        expect(
          tester
              .widget<SelectableText>(
                find.byKey(const Key('tp-network-endpoint')),
              )
              .data,
          startsWith('http://'),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'teacher home directs students to QR browser access without installed join form',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1100, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(const app.ElectroSimApp());
        expect(find.text('Créer une nouvelle session'), findsOneWidget);
        expect(find.text('Centre de maintenance'), findsOneWidget);
        expect(find.text('Centre de conception'), findsOneWidget);
        expect(find.byKey(const Key('home-join-panel')), findsOneWidget);
        expect(find.text('Accès élèves sans installation'), findsOneWidget);
        expect(find.byKey(const Key('home-join-session')), findsNothing);
        expect(find.byKey(const Key('join-session-endpoint')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    test(
      'teacher server serves offline student Web bundle and tracks browser identity',
      () async {
        final Directory webRoot = await Directory.systemTemp.createTemp(
          'electrosim-student-web-',
        );
        await File(
          '${webRoot.path}/index.html',
        ).writeAsString('<!doctype html><title>ElectroSim Élève</title>');
        await File(
          '${webRoot.path}/main.dart.js',
        ).writeAsString('console.log("student");');

        final ElectroSimTpSessionController teacher =
            ElectroSimTpSessionController();
        final ElectroSimLanSyncHost host = ElectroSimLanSyncHost(
          controller: teacher,
          sessionCode: 'WEB234',
          sessionName: 'Atelier BEP1',
          studentWebRoot: webRoot,
        );
        final ElectroSimLanHostInfo info = await host.start(
          address: InternetAddress.loopbackIPv4,
        );
        Socket? httpSocket;
        WebSocket? browserSocket;
        StreamSubscription<dynamic>? browserSubscription;
        final List<Map<String, dynamic>> messages = <Map<String, dynamic>>[];

        addTearDown(() async {
          await browserSubscription?.cancel();
          await browserSocket?.close();
          httpSocket?.destroy();
          await host.close();
          teacher.dispose();
          await webRoot.delete(recursive: true);
        });

        expect(info.preferredJoinUrl.scheme, 'http');
        expect(info.preferredJoinUrl.path, '/join/WEB234');

        httpSocket = await Socket.connect(
          info.preferredJoinUrl.host,
          info.preferredJoinUrl.port,
        );
        httpSocket.write(
          'GET ${info.preferredJoinUrl.path} HTTP/1.1\r\n'
          'Host: ${info.preferredJoinUrl.host}\r\n'
          'Connection: close\r\n'
          '\r\n',
        );
        await httpSocket.flush();
        final String rawHttp = await utf8.decoder.bind(httpSocket).join();
        expect(rawHttp, startsWith('HTTP/1.1 200'));
        expect(rawHttp, contains('ElectroSim Élève'));

        final Uri socketUri = info.preferredEndpoint.replace(
          queryParameters: <String, String>{
            'code': 'WEB234',
            'clientId': 'browser-awa',
            'displayName': 'Awa Ouédraogo',
          },
        );
        browserSocket = await WebSocket.connect(socketUri.toString());
        browserSubscription = browserSocket.listen((dynamic data) {
          if (data is String) {
            final Object? decoded = jsonDecode(data);
            if (decoded is Map<String, dynamic>) {
              messages.add(decoded);
            }
          }
        });

        await _waitFor(() => host.connectedStudents.length == 1);
        expect(host.connectedStudents.single.clientId, 'browser-awa');
        expect(host.connectedStudents.single.displayName, 'Awa Ouédraogo');

        await _waitFor(() => messages.isNotEmpty);
        expect(
          (messages.last['payload'] as Map<String, dynamic>)['session'],
          isA<Map<String, dynamic>>(),
        );

        host.setSessionStarted(true);
        await _waitFor(
          () => messages.any((Map<String, dynamic> envelope) {
            final Object? payload = envelope['payload'];
            if (payload is! Map<String, dynamic>) return false;
            final Object? session = payload['session'];
            return session is Map<String, dynamic> &&
                session['started'] == true &&
                session['simulatorEnabled'] == true;
          }),
        );

        host.closeClassroomSession();
        await _waitFor(
          () => messages.any((Map<String, dynamic> envelope) {
            final Object? payload = envelope['payload'];
            if (payload is! Map<String, dynamic>) return false;
            final Object? session = payload['session'];
            return session is Map<String, dynamic> &&
                session['closed'] == true &&
                session['simulatorEnabled'] == false;
          }),
        );
      },
    );

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
